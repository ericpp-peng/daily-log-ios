//
//  PermissionViews.swift
//  daily-log-ios
//

import SwiftUI

struct PermissionRequestView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            VStack(spacing: 10) {
                Text("Access Your Photos")
                    .font(.title2.bold())

                Text("We need access to your photo library so you can choose photos and videos for your daily log. Your media stays on your iPhone unless you choose to export or share it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Allow Access", action: onRequest)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 13)
                .background(Color.orange)
                .clipShape(Capsule())

            Spacer()
        }
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Text("Photo Access Required")
                    .font(.title2.bold())

                Text("Photo access is required to create your daily log. You can enable access in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 13)
            .background(Color.orange)
            .clipShape(Capsule())

            Spacer()
        }
    }
}
