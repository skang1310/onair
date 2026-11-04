import SwiftUI
import UIKit

@MainActor final class CanvasInteractionGate {
    private var interacting=false
    private var blockedUntil=0.0
    var isBlocked:Bool { interacting || ProcessInfo.processInfo.systemUptime < blockedUntil }
    func begin() { interacting=true }
    func end() { interacting=false;blockedUntil=ProcessInfo.processInfo.systemUptime+0.25 }
}

/// Native scroll-view zoom keeps the point between the fingers anchored and cancels taps while pinching.
struct PinchZoomCanvas<Content: View>: UIViewRepresentable {
    @Binding var zoom: CGFloat
    let canvasWidth: CGFloat
    var revision: Int = 0
    var interactionGate:CanvasInteractionGate? = nil
    var focusPoint:CGPoint? = nil
    var focusRevision:Int = 0
    @ViewBuilder var content: Content

    func makeCoordinator() -> Coordinator { Coordinator(zoom: $zoom, content: content,gate:interactionGate) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = FocusScrollView()
        scroll.delegate = context.coordinator
        context.coordinator.revision = revision
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.bouncesZoom = false
        scroll.pinchGestureRecognizer?.isEnabled = false
        let pinch=UIPinchGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.handlePinch(_:)))
        pinch.delegate=context.coordinator
        pinch.cancelsTouchesInView=true
        scroll.addGestureRecognizer(pinch)
        scroll.panGestureRecognizer.maximumNumberOfTouches=1
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = true
        scroll.clipsToBounds = true
        scroll.backgroundColor = .clear
        context.coordinator.host.view.backgroundColor = .clear
        scroll.addSubview(context.coordinator.host.view)
        configure(scroll, coordinator: context.coordinator)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.zoom = $zoom
        coordinator.gate=interactionGate
        if coordinator.revision != revision || abs(coordinator.width-canvasWidth)>0.5 {
            coordinator.host.rootView = content
            coordinator.revision = revision
        }
        configure(scroll, coordinator: coordinator)
    }
    private func configure(_ scroll: UIScrollView, coordinator: Coordinator) {
        coordinator.programmatic = true
        defer { coordinator.programmatic = false }
        let width = max(1, canvasWidth)
        if abs(coordinator.width - width) > 0.5 {
            scroll.setZoomScale(1, animated: false)
            coordinator.width = width
            coordinator.host.view.frame = CGRect(x: 0, y: 0, width: width, height: width)
            scroll.contentSize = CGSize(width: width, height: width)
        }
        let requested = min(4, max(1, zoom))
        if !coordinator.userZooming && !scroll.isZooming && abs(scroll.zoomScale - requested) > 0.002 {
            // Button zoom shares the gesture's scale and stays centered on the visible area.
            let center = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                 y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
            scroll.setZoomScale(requested, animated: false)
            let maxX = max(0, scroll.contentSize.width - scroll.bounds.width)
            let maxY = max(0, scroll.contentSize.height - scroll.bounds.height)
            scroll.contentOffset = CGPoint(x: min(maxX, max(0, center.x * requested - scroll.bounds.width / 2)),
                                           y: min(maxY, max(0, center.y * requested - scroll.bounds.height / 2)))
        }
        if let point=focusPoint,coordinator.lastFocus != focusRevision {
            coordinator.lastFocus=focusRevision
            if let focused=scroll as? FocusScrollView {focused.pendingFocus=point;focused.baseWidth=width;focused.setNeedsLayout()}
        }
    }
    static func dismantleUIView(_ scroll: UIScrollView, coordinator: Coordinator) { coordinator.gate?.end();scroll.delegate = nil }

    @MainActor final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var zoom: Binding<CGFloat>
        var host: UIHostingController<Content>
        var width: CGFloat = 0
        var programmatic = false
        var revision: Int?
        var gate:CanvasInteractionGate?
        var lastFocus:Int?
        var userZooming=false
        var initialScale:CGFloat=1
        var anchor=CGPoint.zero
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer)->Bool {
            // SwiftUI hosts its own recognizers. Allow zoom to coexist, and gate game taps separately.
            gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
        }
        @objc func handlePinch(_ pinch:UIPinchGestureRecognizer) {
            guard let scroll=pinch.view as? UIScrollView else { return }
            let location=pinch.location(in:scroll)
            if pinch.state == .began {
                gate?.begin();userZooming=true;initialScale=scroll.zoomScale
                anchor=CGPoint(x:location.x/initialScale,y:location.y/initialScale)
            }
            if pinch.state == .began || pinch.state == .changed {
                let viewport=CGPoint(x:location.x-scroll.contentOffset.x,y:location.y-scroll.contentOffset.y)
                let scale=min(4,max(1,initialScale*pinch.scale))
                programmatic=true
                scroll.setZoomScale(scale,animated:false)
                scroll.contentOffset=CGPoint(x:min(max(0,scroll.contentSize.width-scroll.bounds.width),max(0,anchor.x*scale-viewport.x)),y:min(max(0,scroll.contentSize.height-scroll.bounds.height),max(0,anchor.y*scale-viewport.y)))
                programmatic=false
                zoom.wrappedValue=scale
            }
            if pinch.state == .ended || pinch.state == .cancelled || pinch.state == .failed { if userZooming { gate?.end() };userZooming=false }
        }
        init(zoom: Binding<CGFloat>, content: Content,gate:CanvasInteractionGate?) { self.zoom = zoom;self.gate=gate;host = UIHostingController(rootView: content) }
        func scrollViewWillBeginDragging(_ scrollView:UIScrollView) { gate?.begin() }
        func scrollViewDidEndDragging(_ scrollView:UIScrollView,willDecelerate decelerate:Bool) { if !decelerate { gate?.end() } }
        func scrollViewDidEndDecelerating(_ scrollView:UIScrollView) { gate?.end() }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard !programmatic else { return }
            let value = min(4, max(1, scrollView.zoomScale))
            if abs(zoom.wrappedValue - value) > 0.001 { zoom.wrappedValue = value }
        }
    }
}

/// Camera requests are applied after UIKit lays out the zoomed content.
@MainActor private final class FocusScrollView:UIScrollView {
    var pendingFocus:CGPoint?
    var baseWidth:CGFloat=1
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width>0,bounds.height>0,let point=pendingFocus else {return}
        pendingFocus=nil
        let target=CGPoint(x:min(max(0,contentSize.width-bounds.width),max(0,point.x*baseWidth*zoomScale-bounds.width/2)),y:min(max(0,contentSize.height-bounds.height),max(0,point.y*baseWidth*zoomScale-bounds.height/2)))
        setContentOffset(target,animated:false)
    }
}
