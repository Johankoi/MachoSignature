//
//  main.swift
//  macho-sign
//
//  Created by johankoi on 2021/8/23.
//

import Foundation
import Commander

Group {
  $0.command("install") {
    print("Installing Pods")
  }

  $0.command("upgrade") { (name:String) in
    print("Updating \(name)")
  }

  $0.command("search",
    Option("name", default: "world"),
    Option("count", default: 1, description: "The number of times to print."),
    Flag("web", description: "Searches on cocoapods.org"),
//    Argument<String>("query"),
    description: "Perform a search"
  ) {  name,count,web  in
//    if web {
//      print("Searching for \(query) on the web.")
//    } else {
//      print("Locally searching for \(query).")
//    }
  }
}.run()


