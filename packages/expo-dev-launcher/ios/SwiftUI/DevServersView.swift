// Copyright 2015-present 650 Industries. All rights reserved.

import SwiftUI

// swiftlint:disable closure_body_length

private func sanitizeUrlString(_ urlString: String) -> String? {
  var sanitizedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

  if let decodedUrl = sanitizedUrl.removingPercentEncoding {
    sanitizedUrl = decodedUrl
  }

  if !sanitizedUrl.contains("://") {
    sanitizedUrl = "http://" + sanitizedUrl
  }

  guard URL(string: sanitizedUrl) != nil else {
    return nil
  }

  return sanitizedUrl
}

private let urlInputAnimation = Animation.easeInOut(duration: 0.3)
private let keyboardShortcuts = ["http://", "https://", "127.0.0.1", ":", "/"]

struct DevServersView: View {
  @EnvironmentObject var viewModel: DevLauncherViewModel
  @Binding var showingInfoDialog: Bool
  @State private var showingURLInput = false
  @State private var urlText = ""

  private func connectToURL() {
    if !urlText.isEmpty {
      let sanitizedURL = sanitizeUrlString(urlText)
      if let validURL = sanitizedURL {
        viewModel.openApp(url: validURL)
        withAnimation(urlInputAnimation) {
          showingURLInput = false
        }
        urlText = ""
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header

      LazyVStack(alignment: .leading, spacing: 6) {
        if viewModel.devServers.isEmpty {
          if viewModel.permissionStatus != .denied {
            HStack {
              Text("Searching for development servers...")
                .foregroundColor(.secondary)
              Spacer()
              ProgressView()
                .controlSize(.small)
            }
            .padding()
            Divider()
          }
        } else {
          ForEach(viewModel.devServers, id: \.self) { server in
            DevServerRow(server: server) {
              viewModel.openApp(url: server.url)
            }
          }
        }
        if viewModel.hasEmbeddedBundle {
          embeddedBundleRow
        }
        if viewModel.conductorRemoteBuildsURL != nil {
          conductorRemoteBuildsRow
        }
        enterUrl
      }
    }
  }

  private var conductorRemoteBuildsRow: some View {
    HStack {
      Image(systemName: "icloud.and.arrow.down")
        .foregroundColor(conductorRemoteBuildsStatusColor)
        .frame(width: 12)
      VStack(alignment: .leading, spacing: 2) {
        Text("Remote builds")
          .foregroundColor(.primary)
        Text(conductorRemoteBuildsStatusText)
          .font(.caption)
          .foregroundColor(conductorRemoteBuildsStatusColor)
      }
      Spacer()
      Button {
        Task {
          await viewModel.refreshConductorRemoteBuilds()
        }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 28, height: 28)
      }
      .disabled(viewModel.conductorRemoteBuildsStatus == .checking)
      .buttonStyle(PlainButtonStyle())

      if isConductorRemoteBuildsActionable {
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 20, height: 20)
      }
    }
    .padding()
    .contentShape(Rectangle())
    .onTapGesture {
      if isConductorRemoteBuildsActionable {
        viewModel.showConductorRemoteBuilds()
      }
    }
    .background(Color.expoSecondarySystemBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var isConductorRemoteBuildsActionable: Bool {
    viewModel.conductorRemoteBuildsStatus == .needsAuthentication
  }

  private var conductorRemoteBuildsStatusText: String {
    switch viewModel.conductorRemoteBuildsStatus {
    case .checking:
      return "Checking connection"
    case .connected:
      return "Connected"
    case .needsAuthentication:
      return "Sign in needed"
    case .disconnected:
      return "Disconnected"
    case .unreachable:
      return "Not reachable"
    }
  }

  private var conductorRemoteBuildsStatusColor: Color {
    switch viewModel.conductorRemoteBuildsStatus {
    case .checking:
      return .secondary
    case .connected:
      return .green
    case .needsAuthentication:
      return .orange
    case .disconnected:
      return .secondary
    case .unreachable:
      return .red
    }
  }

  private var enterUrl: some View {
    VStack(spacing: 20) {
      Button {
        withAnimation(urlInputAnimation) {
          showingURLInput.toggle()
        }
      } label: {
        HStack {
          Image(systemName: "chevron.right")
            .font(.headline)
            .rotationEffect(.degrees(showingURLInput ? 90 : 0))
          Text("Enter URL manually")
            #if os(tvOS)
            .font(.system(size: 28))
            #else
            .font(.system(size: 14))
            #endif
          Spacer()
          if viewModel.isLoadingServer && viewModel.devServers.isEmpty {
            ProgressView()
          }
        }
      }

      if showingURLInput {
        TextField("http://", text: $urlText)
          .onSubmit {
            connectToURL()
          }
          .submitLabel(.go)
        #if !os(macOS)
          .keyboardType(.URL)
          .autocapitalization(.none)
        #endif
          .disableAutocorrection(true)
          .toolbar {
            #if os(tvOS)
            ToolbarItemGroup(placement: .automatic) {
              ForEach(keyboardShortcuts, id: \.self) { shortcut in
                Button {
                  urlText += shortcut
                } label: {
                  Text(shortcut)
                }
              }
            }
            #else
            ToolbarItemGroup(placement: .keyboard) {
              ForEach(keyboardShortcuts, id: \.self) { shortcut in
                Button {
                  urlText += shortcut
                } label: {
                  Text(shortcut)
                }
              }
            }
            #endif
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .foregroundColor(.primary)
        #if !os(tvOS)
          .overlay(
            RoundedRectangle(cornerRadius: 5)
              .stroke(Color.expoSystemGray4, lineWidth: 1)
          )
        #endif
          .clipShape(RoundedRectangle(cornerRadius: 5))

        connectButton
      }
    }
    .animation(urlInputAnimation, value: showingURLInput)
    .padding()
    .background(showingURLInput ?
      Color.expoSecondarySystemBackground :
      Color.expoSystemBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var embeddedBundleRow: some View {
    Button {
      viewModel.loadLocalBundle()
    } label: {
      HStack {
        Image(systemName: "doc.fill")
          .foregroundColor(.blue)
          .frame(width: 12)
        Text("Open Conductor Dev")
          .foregroundColor(.primary)
        Spacer()
        Group {
          if viewModel.isLoadingLocalBundle {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .frame(width: 20, height: 20)
      }
      .padding()
      .background(Color.expoSecondarySystemBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(PlainButtonStyle())
  }

  private var header: some View {
    HStack {
      Text("development servers".uppercased())
        .font(.caption)
        .foregroundColor(.primary.opacity(0.6))

      Spacer()

      Button {
        showingInfoDialog = true
      } label: {
        Text("info".uppercased())
          #if os(tvOS)
          .foregroundColor(.primary)
          .font(.system(size: 24))
          #else
          .font(.system(size: 12))
          #endif
      }
      .buttonStyle(.automatic)
    }
  }

  private var connectButton: some View {
    Button {
      connectToURL()
    } label: {
      Text("Connect")
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(urlText.isEmpty ? Color.gray : Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .disabled(urlText.isEmpty)
    .buttonStyle(.plain)
  }
}

struct DevServerRow: View {
  @EnvironmentObject var viewModel: DevLauncherViewModel
  let server: DevServer
  let onTap: () -> Void

  var body: some View {
    Button {
      onTap()
    }
    label: {
      HStack {
        Circle()
          .fill(Color.green)
          .frame(width: 12, height: 12)

        if server.description == server.url {
          Text(server.description)
            .foregroundColor(.primary)
            .lineLimit(1)
        } else {
          VStack(alignment: .leading) {
            Text(server.description)
              .font(.headline)
              .foregroundColor(.primary)
              .lineLimit(1)
            Text(server.url)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        Group {
          if viewModel.isLoadingServer {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .frame(width: 20, height: 20)
      }
      .padding()
      .background(Color.expoSecondarySystemBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(PlainButtonStyle())
  }
}
// swiftlint:enable closure_body_length
