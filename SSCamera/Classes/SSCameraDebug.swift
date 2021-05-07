//
//  SSCameraDebug.swift
//  SSCamera
//
//  Created by 2020 on 2021/5/7.
//

import Foundation
func debug(_ items: Any...,
                separator: String = " ",
                terminator: String = "\n",
                file: String = #file,
                line: Int = #line,
                method: String = #function)
{
    #if DEBUG
        print("SSCameraDebug ","\((file as NSString).lastPathComponent)[\(line)], \(method):", terminator: separator)
        var i = 0
        let j = items.count
        for a in items {
            i += 1
            print(" ",a, terminator:i == j ? terminator: separator)
        }
    #endif
}
