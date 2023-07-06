//
//  ContentView.swift
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

import SwiftUI

struct ContentView: View {
    @State var numberOfThreads: Int = 25
    @State var arrayOffset: Int = 0
    @State var libraryToExtract: Library = Libraries.list[0]
    @State var showingAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
                .frame(minWidth: 30)
            HStack {
                Spacer()
                    .frame(width: 30)
                Text("Library to Symbolicate")
                Spacer()
                Picker("", selection: $libraryToExtract) {
                    ForEach(Libraries.list, id: \.self) {
                        Text($0.name)
                    }
                }
                Spacer()
                    .frame(width: 30)
            }

            HStack {
                Spacer()
                    .frame(width: 30)
                Stepper(value: $numberOfThreads, in: 10...40) {
                    Text("Number of threads: \(numberOfThreads)")
                }
                Spacer()
                    .frame(width: 30)
            }

            HStack {
                Spacer()
                    .frame(width: 30)
                Stepper(value: $arrayOffset, in: 0...40) {
                    Text("Offset: \(arrayOffset)")
                }
                Spacer()
                    .frame(width: 30)
            }

            Button("Crash") {
                showingAlert = !EMGCrasher().crash(libraryToExtract,
                                                   numberOfThreads,
                                                   arrayOffset)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
                .padding(.all)
                .frame(minWidth: 30)
        }
        .alert("There are no more symbols to extract", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
