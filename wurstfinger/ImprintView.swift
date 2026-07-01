//
//  ImprintView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct ImprintView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Akator GmbH")
                        .font(.headline)
                    Text("Mozartstr. 13")
                    Text("49740 Haselünne")
                    Text("Germany")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Managing directors: Claas Flint, Dr. Sven Willner")
                        Text("Register court: Amtsgericht Osnabrück · HRB 220235")
                        Text("VAT ID (§ 27a UStG): DE367322752")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Information according to § 5 DDG")
            }

            Section {
                Link(destination: URL(string: "mailto:info@akator.de")!) {
                    HStack {
                        Image(systemName: "envelope")
                        Text("info@akator.de")
                    }
                }
            } header: {
                Text("Contact")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The provider assumes no liability for the accuracy, completeness and timeliness of the content provided.")
                        .font(.footnote)

                    Text(
                        // swiftlint:disable:next line_length
                        "Liability claims against the provider relating to material or immaterial damage caused by the use or non-use of the information provided are excluded."
                    )
                    .font(.footnote)
                }
                .foregroundColor(.secondary)
            } header: {
                Text("Disclaimer")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This app is a free open-source project provided under the MIT License.")
                        .font(.footnote)

                    Text("The app does not collect any personal data and does not send any information to external servers.")
                        .font(.footnote)

                    Link(destination: URL(string: "https://github.com/cl445/wurstfinger")!) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("Source Code on GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                        }
                        .font(.footnote)
                    }
                }
            } header: {
                Text("Open Source & Privacy")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EU Dispute Resolution")
                        .font(.footnote)
                        .fontWeight(.semibold)

                    Text("The European Commission provides a platform for online dispute resolution (ODR):")
                        .font(.footnote)

                    Link(destination: URL(string: "https://ec.europa.eu/consumers/odr")!) {
                        Text("https://ec.europa.eu/consumers/odr")
                            .font(.footnote)
                    }

                    Text("We are not willing or obligated to participate in dispute resolution proceedings before a consumer arbitration board.")
                        .font(.footnote)
                        .padding(.top, 4)
                }
                .foregroundColor(.secondary)
            } header: {
                Text("Consumer Dispute Resolution")
            }
        }
        .navigationTitle("Imprint")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        ImprintView()
    }
}
