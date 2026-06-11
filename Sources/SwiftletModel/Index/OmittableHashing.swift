//
//  OmittableHashing.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 12/03/2025.
//

import Foundation
 
public protocol OmittableFromHashing: Hashable { }
 
extension OmittableFromHashing {
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
    public func hash(into hasher: inout Hasher) { }
}
  
