//  HoverButton.swift
//  Hippo
//
//  Created by Hama on 11/12/25.
//

import SwiftUI
import Lottie

/// 기본 원형 버튼 위에 Lottie hoverIn/hoverOut을 얹어 동작:
/// - hover 전: hoverIn 0프레임 정지 (hoverOut 숨김)
/// - hover 시작: hoverIn 1회 재생 중 (hoverOut 숨김)
/// - hover 유지: hoverIn 끝 프레임 정지 (hoverOut 숨김)
/// - hover 종료: hoverOut 1회 재생 중 (hoverIn 숨김) → 끝나면 초기 상태
struct MenuToggleButton: View {
    // 외부 설정
    var size: CGFloat = 120
    var action: () -> Void = {}

    // 상태 머신
    private enum HoverAnimState: Equatable {
        case idle            // hover 전: hoverIn 0프레임 정지
        case playingIn       // hover 시작 후: hoverIn 재생 중
        case hoveredHold     // hover 유지: hoverIn 끝 프레임 정지
        case playingOut      // hover 종료 후: hoverOut 재생 중
    }

    @Environment(ImmersiveViewModel.self) private var immersiveViewModel
    @State private var state: HoverAnimState = .idle
    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            Color.clear
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .opacity(immersiveViewModel.isMenuActive ? 1.0 : 0.25)
        .onTapGesture(perform: action)
        .overlay {
            ZStack {
                // hoverIn 레이어
                LottieView(animation: .named("hoverIn"))
                    .resizable()
                    .playbackMode(hoverInPlaybackMode(for: state))
                    .animationDidFinish { _ in
                        // hoverIn 재생이 끝나면, 여전히 hover 중이면 hoveredHold로 고정
                        if state == .playingIn {
                            state = isHovering ? .hoveredHold : .idle
                        }
                    }
                    .frame(width: size, height: size)
                    .opacity(hoverInVisible(for: state) ? 1 : 0)

                // hoverOut 레이어
                LottieView(animation: .named("hoverOut"))
                    .resizable()
                    .playbackMode(hoverOutPlaybackMode(for: state))
                    .animationDidFinish { _ in
                        // hoverOut 재생이 끝나면 idle로 복귀
                        if state == .playingOut {
                            state = .idle
                        }
                    }
                    .frame(width: size, height: size)
                    .opacity(hoverOutVisible(for: state) ? 1 : 0)
            }
            .allowsHitTesting(false)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovering = true
                // idle 또는 playingOut 중일 때만 hoverIn 재생 시작
                switch state {
                case .idle, .playingOut:
                    state = .playingIn
                case .playingIn, .hoveredHold:
                    break
                }
            case .ended:
                isHovering = false
                // playingIn 중이면 끝까지 재생되도록 두고, 끝난 뒤 out 재생할지 결정
                // hoveredHold 상태에서는 바로 out 재생 시작
                switch state {
                case .hoveredHold:
                    state = .playingOut
                case .playingIn, .idle, .playingOut:
                    // playingIn: completion에서 isHovering == false면 idle로 내려앉음
                    // idle: 그대로
                    // playingOut: 그대로
                    break
                }
            }
        }
    }

    // MARK: - Visibility

    private func hoverInVisible(for state: HoverAnimState) -> Bool {
        switch state {
        case .idle, .playingIn, .hoveredHold:
            return true
        case .playingOut:
            return false
        }
    }

    private func hoverOutVisible(for state: HoverAnimState) -> Bool {
        switch state {
        case .playingOut:
            return true
        case .idle, .playingIn, .hoveredHold:
            return false
        }
    }

    // MARK: - Playback Modes

    private func hoverInPlaybackMode(for state: HoverAnimState) -> LottiePlaybackMode {
        switch state {
        case .idle:
            // 시작 프레임에서 정지
            return .paused(at: .progress(0))
        case .playingIn:
            // 0 -> 1 한 번 재생
            return .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
        case .hoveredHold:
            // 끝 프레임에서 정지
            return .paused(at: .progress(1))
        case .playingOut:
            // 보이지 않게 하고, 내부적으로도 정지
            return .paused(at: .progress(0))
        }
    }

    private func hoverOutPlaybackMode(for state: HoverAnimState) -> LottiePlaybackMode {
        switch state {
        case .playingOut:
            // 0 -> 1 한 번 재생
            return .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
        case .idle, .playingIn, .hoveredHold:
            // 보이지 않는 동안엔 0프레임에서 정지
            return .paused(at: .progress(0))
        }
    }
}
