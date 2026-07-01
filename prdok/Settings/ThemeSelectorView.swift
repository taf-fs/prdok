//
//  ThemeSelectorView.swift
//  prdok
//
//  Created by David Horňák on 29.06.2026.
//

import SwiftUI

struct ThemeSelectorView: View {
    @Binding var theme: Theme

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { theme = .light }
            } label: {
                VStack(spacing: 16) {
                    LightThemePreview()
                    Text("themePicker.Light")
                    Spacer().frame(maxHeight: 0)
                    SelectionIndicator(isSelected: theme == .light)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { theme = .dark }
            } label: {
                VStack(spacing: 16) {
                    DarkThemePreview()
                    Text("themePicker.dark")
                    Spacer().frame(maxHeight: 0)
                    SelectionIndicator(isSelected: theme == .dark)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { theme = .system }
            } label: {
                VStack(spacing: 16) {
                    SystemThemePreview()
                    Text("themePicker.system")
                    Spacer().frame(maxHeight: 0)
                    SelectionIndicator(isSelected: theme == .system)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func SelectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.cpForegroundSecondary),
                isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.cpForegroundSecondary)
            )
    }
}

private struct LightThemePreview: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .aspectRatio(1, contentMode: .fit)
            .foregroundStyle(.white)
            .shadow(radius: 1)
            .overlay {
                Image("cpLogo")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            }
    }
}

private struct DarkThemePreview: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .aspectRatio(1, contentMode: .fit)
            .foregroundStyle(.black)
            .shadow(radius: 1)
            .overlay {
                Image("cpLogoDark")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            }
    }
}

private struct SystemThemePreview: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .aspectRatio(1, contentMode: .fit)
            .foregroundStyle(.white)
            .shadow(radius: 1)
            .overlay {
                VerticalSplit()
                    .foregroundStyle(.black)
            }
            .overlay {
                GeometryReader { geo in
                    Image("cpLogoDark")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .mask(VerticalSplit().frame(width: geo.size.width, height: geo.size.height))

                    Image("cpLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .mask(
                            VerticalSplit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .rotationEffect(.degrees(180)) // inverse half
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DiagonalSplit: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY)) // top-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // bottom-right
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // bottom-left
        path.closeSubpath()
        return path
    }
}

struct VerticalSplit: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
        return path
    }
}

#Preview {
    ThemeSelectorView(theme: .constant(.system))
        .padding()
}
