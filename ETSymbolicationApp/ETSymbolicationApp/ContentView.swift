//
//  ContentView.swift
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

import SwiftUI

struct ContentView: View {
  @State var numberOfThreads: Int
  @State var arrayOffset: Int
  @State var libraryToExtract: Library = Libraries.list[0]
  @State var showingAlert: Bool = false

  enum Constants {
    static let offsetKey = "offset"
    static let threadsKey = "threads"
  }

  init() {
    numberOfThreads = ContentView.value(Constants.threadsKey, defaultValue: 25)
    arrayOffset = ContentView.value(Constants.offsetKey, defaultValue: 0)
  }

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
        UIPasteboard.general.string = "Threads: \(numberOfThreads)\nOffset: \(arrayOffset)"
        UserDefaults.standard.set(arrayOffset + 1, forKey: Constants.offsetKey)
        UserDefaults.standard.set(numberOfThreads, forKey: Constants.threadsKey)
        UserDefaults.standard.synchronize()

        showingAlert = !EMGCrasher().crash(
          libraryToExtract,
          numberOfThreads,
          arrayOffset)
        if showingAlert {
          UserDefaults.standard.set(0, forKey: Constants.offsetKey)
        }
      }
      .buttonStyle(.borderedProminent)

      Spacer()
        .padding(.all)
        .frame(minWidth: 30)
    }
    .alert("There are no more symbols to extract", isPresented: $showingAlert) {
      Button("OK", role: .cancel) {}
    }
  }

  static func value(_ name: String, defaultValue: Int) -> Int {
    let userDefaults = UserDefaults.standard
    return userDefaults.value(forKey: name) != nil
      ? userDefaults.integer(forKey: name) : defaultValue
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
