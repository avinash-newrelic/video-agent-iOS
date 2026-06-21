#if os(iOS)
import SwiftUI
import AVKit
import UIKit
import GoogleInteractiveMediaAds
import NewRelicVideoCore

/// Plays content + Google IMA ads with NRVA tracking on both.
///
/// NRVA flow:
///   1. Register the AVPlayer with `adEnabled: true` so the agent loads
///      `NRTrackerIMA` for the ad tracker side of the pair.
///   2. On every IMA delegate callback, forward to:
///        NRVAVideo.handleAdEvent(_:event:adsManager:)
///        NRVAVideo.handleAdError(_:error:adsManager:)
///        NRVAVideo.sendAdBreakStart(_:)
///        NRVAVideo.sendAdBreakEnd(_:)
///   3. Standard content events (CONTENT_REQUEST, CONTENT_START, etc.) are
///      generated automatically by the AVPlayer side via NRTrackerAVPlayer.
struct IMAPlayerView: View {
    let item: ContentItem

    var body: some View {
        IMAHosted(item: item)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IMAHosted: UIViewControllerRepresentable {
    let item: ContentItem

    func makeUIViewController(context: Context) -> IMAPlayerVC {
        IMAPlayerVC(item: item)
    }

    func updateUIViewController(_ vc: IMAPlayerVC, context: Context) {}
}

/// UIKit view controller hosting the AVPlayerLayer + IMA SDK.
final class IMAPlayerVC: UIViewController,
                        IMAAdsLoaderDelegate,
                        IMAAdsManagerDelegate {

    private let item: ContentItem
    private var avPlayer: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var contentPlayhead: IMAAVPlayerContentPlayhead?
    private var adsLoader: IMAAdsLoader?
    private var adsManager: IMAAdsManager?
    private var nrvaTrackerId: Int = -1
    private var endObserver: NSObjectProtocol?
    private var actionScriptTask: Task<Void, Never>?

    init(item: ContentItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from storyboard") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupContentPlayer()
        setupIMA()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    // MARK: - Content player + NRVA registration

    private func setupContentPlayer() {
        let player = AVPlayer(url: item.streamURL)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.addSublayer(layer)

        avPlayer = player
        playerLayer = layer
        contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)

        // Level 2 NRVA config — ad-enabled this time so NRVA pairs the
        // content tracker with an NRTrackerIMA ad tracker.
        nrvaTrackerId = NewRelicSetup.addAVPlayer(
            player,
            name: item.id,
            adEnabled: true,
            customAttributes: [
                "contentTitle": item.title,
                "isLive": item.isLive,
            ]
        )
        AppLog.shared.log(.event, "IMAPlayer", "tracker added",
                          ["trackerId": nrvaTrackerId, "id": item.id])

        // NRVA's viewId is assigned on the first event — give it ~2 s, then
        // log it so the CI runner extracts it into SUMMARY.
        Task { @MainActor [trackerId = nrvaTrackerId] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if let viewId = NewRelicSetup.getViewId(trackerId: trackerId) {
                AppLog.shared.log(.event, "IMAPlayer", "NRVA viewId",
                                  ["viewId": viewId])
            }
        }

        // If the scenario has a scripted action sequence, run it. Actions
        // apply directly to the AVPlayer; some seeks during ads may be
        // overridden by IMA's content-playhead control, which is expected.
        if let script = PlayerActionScript.resolve(for: item) {
            AppLog.shared.log(.event, "Scenario", "starting actionScript",
                              ["id": item.id, "steps": script.count])
            actionScriptTask = PlayerActionScript.run(script,
                                                     on: player,
                                                     scenarioId: item.id)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            AppLog.shared.log(.event, "IMAPlayer", "contentDidFinish",
                              ["id": self?.item.id ?? ""])
            self?.adsLoader?.contentComplete()
        }
    }

    // MARK: - IMA setup + delegates

    private func setupIMA() {
        guard let imaTag = item.imaTagURL else {
            AppLog.shared.log(.warn, "IMAPlayer", "no imaTagURL — playing content only",
                              ["id": item.id])
            avPlayer?.play()
            return
        }
        AppLog.shared.log(.event, "IMAPlayer", "ad request",
                          ["tagURL": imaTag.absoluteString.prefix(80) + "…"])

        let settings = IMASettings()
        settings.language = "en"

        let loader = IMAAdsLoader(settings: settings)
        loader.delegate = self
        adsLoader = loader

        let adDisplay = IMAAdDisplayContainer(adContainer: view, viewController: self)
        let request = IMAAdsRequest(
            adTagUrl: imaTag.absoluteString,
            adDisplayContainer: adDisplay,
            contentPlayhead: contentPlayhead,
            userContext: nil
        )
        loader.requestAds(with: request)
    }

    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        AppLog.shared.log(.event, "IMAPlayer", "adsLoader.adsLoaded")
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        let renderingSettings = IMAAdsRenderingSettings()
        adsManager?.initialize(with: renderingSettings)
    }

    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        AppLog.shared.log(.fail, "IMAPlayer", "adsLoader.failed",
                          ["msg": adErrorData.adError.message ?? "(none)"])
        forwardAdError(adErrorData.adError, manager: nil)
        avPlayer?.play()  // fall back to content
    }

    func adsManager(_ adsManager: IMAAdsManager, didReceive event: IMAAdEvent) {
        AppLog.shared.log(.event, "IMAPlayer", "adEvent",
                          ["type": event.typeString])
        forwardAdEvent(event, manager: adsManager)

        switch event.type {
        case .LOADED:
            adsManager.start()
        case .AD_BREAK_STARTED:
            NRVAVideo.sendAdBreakStart(NSNumber(value: nrvaTrackerId))
            avPlayer?.pause()
        case .AD_BREAK_ENDED:
            NRVAVideo.sendAdBreakEnd(NSNumber(value: nrvaTrackerId))
        case .ALL_ADS_COMPLETED:
            avPlayer?.play()
        default:
            break
        }
    }

    func adsManager(_ adsManager: IMAAdsManager, didReceive error: IMAAdError) {
        AppLog.shared.log(.fail, "IMAPlayer", "adsManager.error",
                          ["msg": error.message ?? "(none)"])
        forwardAdError(error, manager: adsManager)
        avPlayer?.play()  // fall back to content
    }

    func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager) {
        avPlayer?.pause()
    }

    func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager) {
        avPlayer?.play()
    }

    // MARK: - NRVA forwarding helpers

    private func forwardAdEvent(_ event: IMAAdEvent, manager: IMAAdsManager?) {
        guard nrvaTrackerId >= 0 else { return }
        NRVAVideo.handleAdEvent(NSNumber(value: nrvaTrackerId),
                                event: event,
                                adsManager: manager)
    }

    private func forwardAdError(_ error: IMAAdError, manager: IMAAdsManager?) {
        guard nrvaTrackerId >= 0 else { return }
        if let manager {
            NRVAVideo.handleAdError(NSNumber(value: nrvaTrackerId),
                                    error: error,
                                    adsManager: manager)
        } else {
            NRVAVideo.handleAdError(NSNumber(value: nrvaTrackerId), error: error)
        }
    }

    deinit {
        actionScriptTask?.cancel()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if nrvaTrackerId >= 0 {
            NewRelicSetup.releaseAVPlayer(trackerId: nrvaTrackerId)
        }
    }
}
#endif
