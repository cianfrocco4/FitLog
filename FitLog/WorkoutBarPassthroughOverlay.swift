//
//  WorkoutBarPassthroughOverlay.swift
//  FitLog
//
//  TabView + .safeAreaInset for the in-progress workout strip creates a large
//  interactive region that swallows taps (tab bar, Coach composer, etc.).
//  This UIHostingController-backed overlay only accepts hits inside the bar.
//

import SwiftUI
import UIKit

enum FitlogWorkoutBarLayout {
    /// Approximate collapsed bar height (material + padding + two-line title).
    static let contentBottomPadding: CGFloat = 92
}

private enum FitlogWorkoutBarContentInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Extra bottom padding for tab roots while the workout strip is visible.
    var fitlogWorkoutBarContentInset: CGFloat {
        get { self[FitlogWorkoutBarContentInsetKey.self] }
        set { self[FitlogWorkoutBarContentInsetKey.self] = newValue }
    }
}

extension View {
    func fitlogWorkoutBarContentInset() -> some View {
        modifier(FitlogWorkoutBarContentInsetModifier())
    }
}

private struct FitlogWorkoutBarContentInsetModifier: ViewModifier {
    @Environment(\.fitlogWorkoutBarContentInset) private var inset

    func body(content: Content) -> some View {
        content.padding(.bottom, inset)
    }
}

// MARK: - UIKit passthrough host

final class PassthroughWorkoutBarContainer: UIView {
    private var hostingController: UIHostingController<AnyView>?

    func configure(root: AnyView) {
        if hostingController == nil {
            let host = UIHostingController(rootView: root)
            host.view.backgroundColor = .clear
            hostingController = host
            addSubview(host.view)
        } else {
            hostingController?.rootView = root
        }
    }

    private static func tabBarChromeHeight(for view: UIView) -> CGFloat {
        guard let window = view.window else { return 83 }
        return 49 + window.safeAreaInsets.bottom
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let hv = hostingController?.view else { return }
        let width = bounds.width
        let fitting = hv.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let h = max(fitting.height, 44)
        let lift = Self.tabBarChromeHeight(for: self)
        let y = bounds.height - h - lift
        hv.frame = CGRect(x: 0, y: y, width: width, height: h)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hv = hostingController?.view else { return nil }
        let p = convert(point, to: hv)
        guard hv.point(inside: p, with: event) else { return nil }
        return hv.hitTest(p, with: event)
    }
}

struct WorkoutBarPassthroughOverlay: UIViewRepresentable {
    @Binding var showPullUp: Bool
    @ObservedObject var currentVM: CurrentWorkoutSessionViewModel
    @ObservedObject var dataVM: DataManager

    func makeUIView(context: Context) -> PassthroughWorkoutBarContainer {
        let v = PassthroughWorkoutBarContainer()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        return v
    }

    func updateUIView(_ uiView: PassthroughWorkoutBarContainer, context: Context) {
        let root = AnyView(
            CurrentWorkoutCollapsedBar(showPullUp: $showPullUp)
                .environmentObject(dataVM)
                .environmentObject(currentVM)
        )
        uiView.configure(root: root)
        uiView.setNeedsLayout()
    }
}
