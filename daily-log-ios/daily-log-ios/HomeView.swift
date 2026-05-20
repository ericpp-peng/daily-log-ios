//
//  HomeView.swift
//  daily-log-ios
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = MediaSelectionViewModel()
    @State private var showDatePicker = false
    @State private var customDate = Date()
    @State private var navigateTo: Date? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Log")
                            .font(.largeTitle.bold())
                        Text("Turn your camera roll into a daily memory.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)

                    // Quick date cards
                    VStack(spacing: 12) {
                        DateCard(
                            label: "Today",
                            date: .now,
                            systemImage: "sun.max.fill",
                            tint: .orange
                        ) {
                            open(.now)
                        }
                        DateCard(
                            label: "Yesterday",
                            date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                            systemImage: "moon.stars.fill",
                            tint: .indigo
                        ) {
                            open(Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Choose date
                    Button {
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.body.weight(.medium))
                            Text("Choose a date")
                                .font(.body.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()
                }

                // Hidden navigation link
                NavigationLink(
                    destination: navigateTo.map { date in
                        MediaGridView(date: date, viewModel: viewModel)
                    },
                    isActive: Binding(
                        get: { navigateTo != nil },
                        set: { if !$0 { navigateTo = nil } }
                    )
                ) {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $customDate) {
                    showDatePicker = false
                    open(customDate)
                }
            }
            .onAppear {
                viewModel.checkPermission()
            }
        }
    }

    private func open(_ date: Date) {
        viewModel.resetSelection()
        viewModel.filter = .all
        navigateTo = date
    }
}

// MARK: - DateCard

private struct DateCard: View {
    let label: String
    let date: Date
    let systemImage: String
    let tint: Color
    let action: () -> Void

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.headline)
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - DatePickerSheet

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .navigationTitle("Choose a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    HomeView()
}
