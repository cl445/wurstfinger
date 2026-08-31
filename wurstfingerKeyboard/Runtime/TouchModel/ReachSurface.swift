//
//  ReachSurface.swift
//  Wurstfinger
//
//  Low-order reach-bias surface fitted from per-key offset means by weighted
//  ridge least squares (spec §3.2, §4.2 Step 2). Ridge keeps the fit
//  well-defined when fewer keys than basis dimensions carry data
//  (rank-deficient → shrinks toward 0): cold-start + split-half safety.
//

import Foundation

/// Polynomial basis over the normalized key position `(u, v) ∈ [0,1]²`.
enum SurfaceBasis: String, Codable {
    /// `[1, u, v]` — used for the data-starved twoThumb split halves (§3.2).
    case linear
    /// `[1, u, v, u·v]` — used for the single-surface one-thumb regimes.
    case bilinear

    var dimension: Int {
        self == .linear ? 3 : 4
    }

    func features(u: Double, v: Double) -> [Double] {
        switch self {
        case .linear: [1, u, v]
        case .bilinear: [1, u, v, u * v]
        }
    }
}

/// A fitted scalar reach surface (predicts one axis of the offset prior).
struct ReachSurface: Codable, Equatable {
    let basis: SurfaceBasis
    let coefficients: [Double]

    static func zero(basis: SurfaceBasis) -> ReachSurface {
        ReachSurface(basis: basis, coefficients: Array(repeating: 0, count: basis.dimension))
    }

    func evaluate(u: Double, v: Double) -> Double {
        let phi = basis.features(u: u, v: v)
        return zip(phi, coefficients).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// Constant term — the "global" offset folded into the surface (§3.3).
    var constant: Double {
        coefficients.first ?? 0
    }
}

/// A weighted observation for the surface fit: per-key mean at its position.
struct SurfacePoint {
    let u: Double
    let v: Double
    let target: Double
    let weight: Double
}

enum ReachSurfaceFitter {
    /// Ridge-regularized weighted least squares: solves
    /// `(ΦᵀWΦ + λI) β = ΦᵀW y`. With zero/sparse data the ridge term makes the
    /// system well-posed and pulls `β → 0` (flat surface).
    static func fit(points: [SurfacePoint], basis: SurfaceBasis, lambda: Double) -> ReachSurface {
        let k = basis.dimension
        var ata = [[Double]](repeating: [Double](repeating: 0, count: k), count: k)
        var atb = [Double](repeating: 0, count: k)
        for p in points where p.weight > 0 {
            let phi = basis.features(u: p.u, v: p.v)
            for i in 0 ..< k {
                atb[i] += p.weight * phi[i] * p.target
                for j in 0 ..< k {
                    ata[i][j] += p.weight * phi[i] * phi[j]
                }
            }
        }
        for i in 0 ..< k {
            ata[i][i] += lambda
        }
        let coeffs = Self.solve(ata, atb) ?? Array(repeating: 0, count: k)
        return ReachSurface(basis: basis, coefficients: coeffs)
    }

    /// Gaussian elimination with partial pivoting for a small system `A x = b`.
    /// Returns `nil` if `A` is (numerically) singular — caller falls back to 0.
    static func solve(_ matrix: [[Double]], _ rhs: [Double]) -> [Double]? {
        let n = rhs.count
        guard n > 0 else { return [] }
        var a = matrix
        var b = rhs
        for col in 0 ..< n {
            var pivot = col
            for row in (col + 1) ..< n where abs(a[row][col]) > abs(a[pivot][col]) {
                pivot = row
            }
            if abs(a[pivot][col]) < 1e-12 { return nil }
            if pivot != col { a.swapAt(col, pivot); b.swapAt(col, pivot) }
            for row in (col + 1) ..< n {
                let factor = a[row][col] / a[col][col]
                guard factor != 0 else { continue }
                for c in col ..< n {
                    a[row][c] -= factor * a[col][c]
                }
                b[row] -= factor * b[col]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = b[row]
            for c in (row + 1) ..< n {
                sum -= a[row][c] * x[c]
            }
            x[row] = sum / a[row][row]
        }
        return x
    }
}
