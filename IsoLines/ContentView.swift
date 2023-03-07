//
//  ContentView.swift
//  IsoLines
//
//  Created by David Smith on 3/7/23.
//

import SwiftUI

struct ElevationPoint:Identifiable, Comparable {
    static func < (lhs: ElevationPoint, rhs: ElevationPoint) -> Bool {
        lhs.elevation < rhs.elevation
    }
    static func idFor(x:Int, y:Int) -> Int {
        return x + y * 1000000000
    }
    
    var id:Int { ElevationPoint.idFor(x: self.x, y: self.y)}
    
    let x:Int
    let y:Int
    
    let lat:Double
    let lon:Double
    
    let elevation:Int
    
    func isoValue(at threshold:Double) -> Int {
        if elevation >= Int(round(threshold)) {
            return 1
        } else {
            return 0
        }
    }
}

class Data:ObservableObject {
    static let shared = Data()
    
    var points:[ElevationPoint]
    var lookup:[Int:ElevationPoint]
    init() {
        let data = Data.readFile(Bundle.main.url(forResource: "data100", withExtension: "block")!.path)
        self.points = data
        var result:[Int:ElevationPoint] = [:]
        for point in data {
            result[point.id] = point
        }
        self.lookup = result
    }
    
    var min:Double {
        return 360.0
    }

    var max:Double {
        return 974.0
    }
    
    func elevationPercent(_ elevation:Int) -> Double {
        return (Double(elevation) - min) / (max - min)
    }

    
    static func readFile(_ path: String) -> [ElevationPoint] {
        errno = 0
        if freopen(path, "r", stdin) == nil {
            perror(path)
            return []
        }
        var result:[ElevationPoint] = []
        while let line = readLine() {
            let parts = line.components(separatedBy: " ")
            if parts.count == 5, let x = Int(parts[0]), let y = Int(parts[1]), let e = Int(parts[4]), let lat = Double(parts[2]), let lon = Double(parts[3]) {
                let point = ElevationPoint(x: x, y: y, lat: lat, lon:lon, elevation: e)
                result.append(point)
                print(point.x, point.y, point.elevation)
            }
        }
        return result
    }
    
    func codeFor(x:Int, y:Int, threshold:Double) -> Int {
        let limit = 100
        guard x < limit - 1 else { return 0}
        guard y < limit && y > 0 else { return 0}
        
        let p0 = lookup[ElevationPoint.idFor(x: x, y: y)]!
        let p1 = lookup[ElevationPoint.idFor(x: x + 1, y: y)]!
        let p2 = lookup[ElevationPoint.idFor(x: x + 1, y: y - 1)]!
        let p3 = lookup[ElevationPoint.idFor(x: x, y: y - 1)]!

        let b0 = p0.isoValue(at: threshold) == 1 ? 8 : 0
        let b1 = p1.isoValue(at: threshold) == 1 ? 4 : 0
        let b2 = p2.isoValue(at: threshold) == 1 ? 2 : 0
        let b3 = p3.isoValue(at: threshold) == 1 ? 1 : 0

        return b0 | b1 | b2 | b3
    }
    
    func valueCodeFor(x:Int, y:Int, threshold:Double) -> (code:Int, p0:Int, p1:Int, p2:Int, p3:Int, threshold:Double)? {
        let limit = 100
        guard x < limit - 1 else { return nil}
        guard y < limit && y > 0 else { return nil}
        
        let p0 = lookup[ElevationPoint.idFor(x: x, y: y)]!
        let p1 = lookup[ElevationPoint.idFor(x: x + 1, y: y)]!
        let p2 = lookup[ElevationPoint.idFor(x: x + 1, y: y - 1)]!
        let p3 = lookup[ElevationPoint.idFor(x: x, y: y - 1)]!

        let b0 = p0.isoValue(at: threshold) == 1 ? 8 : 0
        let b1 = p1.isoValue(at: threshold) == 1 ? 4 : 0
        let b2 = p2.isoValue(at: threshold) == 1 ? 2 : 0
        let b3 = p3.isoValue(at: threshold) == 1 ? 1 : 0

        let code = b0 | b1 | b2 | b3
        return (code:code, p0:p0.elevation, p1:p1.elevation, p2:p2.elevation, p3:p3.elevation, threshold:threshold)
    }
}

struct Isoline:Shape {
    let code:Int
    func path(in rect: CGRect) -> Path {

        let a = CGPoint(x:rect.midX, y:rect.minY)
        let b = CGPoint(x:rect.maxX, y:rect.midY)
        let c = CGPoint(x:rect.midX, y:rect.maxY)
        let d = CGPoint(x:rect.minX, y:rect.midY)
        
        var path = Path()
        switch(code) {
        case 0:  let _ = ""
        
        case 1:
            path.move(to: d)
            path.addLine(to: c)
        
        case 2:
            path.move(to: b)
            path.addLine(to: c)
        
        case 3:
            path.move(to: d)
            path.addLine(to: b)
        
        case 4:
            path.move(to: a)
            path.addLine(to: b)

        case 5:
            path.move(to: a)
            path.addLine(to: d)

            path.move(to: b)
            path.addLine(to: c)

        case 6:
            path.move(to: a)
            path.addLine(to: c)

        case 7:
            path.move(to: a)
            path.addLine(to: d)

        case 8:
            path.move(to: a)
            path.addLine(to: d)

        case 9:
            path.move(to: a)
            path.addLine(to: c)

        case 10:
            path.move(to: a)
            path.addLine(to: b)

            path.move(to: d)
            path.addLine(to: c)

        case 11:
            path.move(to: a)
            path.addLine(to: b)

        case 12:
            path.move(to: d)
            path.addLine(to: b)

        case 13:
            path.move(to: c)
            path.addLine(to: b)

        case 14:
            path.move(to: d)
            path.addLine(to: c)

        case 15:
            let _ = ""
            
        default: let _ = ""
        }
        return path
    }
    
    
   
    
}

struct InterpolatedIsoline:Shape {
    let value:(code:Int, p0:Int, p1:Int, p2:Int, p3:Int, threshold:Double)?
    
    
    func interpolate(first:Double, second:Double, firstValue:Int, secondValue:Int, threshold:Double) -> Double {
        
        let mu = (threshold - Double(firstValue)) / (Double(secondValue) - Double(firstValue))
        return first + mu * (second - first)
        
    }
    
    func path(in rect: CGRect) -> Path {
        guard let value = value else { return Path() }
        let intT = Int(value.threshold)
        
        var a = CGPoint(x:rect.midX, y:rect.minY)
        var b = CGPoint(x:rect.maxX, y:rect.midY)
        var c = CGPoint(x:rect.midX, y:rect.maxY)
        var d = CGPoint(x:rect.minX, y:rect.midY)
        
        a = CGPoint(
            x:interpolate(first: rect.minX, second: rect.maxX, firstValue: value.p0, secondValue: value.p1, threshold: value.threshold),
            y:rect.minY)

        b = CGPoint(
            x:rect.maxX,
            y:interpolate(first: rect.minY, second: rect.maxY, firstValue: value.p1, secondValue: value.p2, threshold: value.threshold))

        c = CGPoint(
            x:interpolate(first: rect.maxX, second: rect.minX, firstValue: value.p2, secondValue: value.p3, threshold: value.threshold),
            y:rect.maxY)

        d = CGPoint(
            x:rect.minX,
            y:interpolate(first: rect.maxY, second: rect.minY, firstValue: value.p3, secondValue: value.p0, threshold: value.threshold))

        var path = Path()
        switch(value.code) {
        case 0:  let _ = ""
        
        case 1:
            path.move(to: d)
            path.addLine(to: c)
        
        case 2:
            path.move(to: b)
            path.addLine(to: c)
        
        case 3:
            path.move(to: d)
            path.addLine(to: b)
        
        case 4:
            path.move(to: a)
            path.addLine(to: b)

        case 5:
            path.move(to: a)
            path.addLine(to: d)

            path.move(to: b)
            path.addLine(to: c)

        case 6:
            path.move(to: a)
            path.addLine(to: c)

        case 7:
            path.move(to: a)
            path.addLine(to: d)

        case 8:
            path.move(to: a)
            path.addLine(to: d)

        case 9:
            path.move(to: a)
            path.addLine(to: c)

        case 10:
            path.move(to: a)
            path.addLine(to: b)

            path.move(to: d)
            path.addLine(to: c)

        case 11:
            path.move(to: a)
            path.addLine(to: b)

        case 12:
            path.move(to: d)
            path.addLine(to: b)

        case 13:
            path.move(to: c)
            path.addLine(to: b)

        case 14:
            path.move(to: d)
            path.addLine(to: c)

        case 15:
            let _ = ""
            
        default: let _ = ""
        }
        return path
    }
    
    
   
    
}

struct ContentView: View {
    @ObservedObject var data = Data.shared
    var body: some View {
        GeometryReader { proxy in
            let boxSize = min(proxy.size.width, proxy.size.height) / 100.0
            ZStack {
                ForEach(data.points){ point in
                    
                    
                    let x = proxy.size.width * 0.5 + (Double(point.x) - 50.0) * boxSize
                    let y = proxy.size.height * 0.5 - (Double(point.y) - 50.0) * boxSize

                    Rectangle()
                        .fill(Color(hue: 0.33 - (data.elevationPercent(point.elevation) / 3.0), saturation: 1.0, brightness: 0.75))
                        .frame(width: boxSize, height:boxSize)
                        .position(x: x, y: y)
                }
                
                ForEach(0..<100) { i in
                    ForEach(0..<100) { j in
                        
                        let x = proxy.size.width * 0.5  + (Double(i) - 50.0) * boxSize
                        let y = proxy.size.height * 0.5 - (Double(j) - 50.0) * boxSize
                
                        ForEach(8..<20) { stride in
                            let index = stride * 50
                            if let value = data.valueCodeFor(x: i, y: j, threshold: Double(index - 1)) {
                                InterpolatedIsoline(value:value)
                                    .stroke(.black, lineWidth:index % 100 == 0 ? 3 : 1)
                                    .frame(width:boxSize, height:boxSize)
                                    .position(x: x, y: y)
                            }
                        }
                        
                        
                    }
                }
                
            }
        }
        .frame(width:1000, height: 1000)
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
