/******************************************************************************
 Copyright (C) 2024 by Patrick Heyer <PatTheMav@users.noreply.github.com>

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 ******************************************************************************/

import Foundation
import Metal

class MetalStageBuffer {
    private static let counterQueue = DispatchQueue(label: "MetalStageBuffer.counterQueue")
    nonisolated(unsafe) private static var liveCount = 0
    nonisolated(unsafe) private static var totalCreated = 0
    nonisolated(unsafe) private static var totalDestroyed = 0

    static func snapshotCounts() -> (live: Int, created: Int, destroyed: Int) {
        return counterQueue.sync {
            (live: liveCount, created: totalCreated, destroyed: totalDestroyed)
        }
    }

    private static func recordCreate() {
        counterQueue.sync {
            liveCount += 1
            totalCreated += 1
        }
    }

    private static func recordDestroy() {
        counterQueue.sync {
            liveCount = max(0, liveCount - 1)
            totalDestroyed += 1
        }
    }

    let device: MetalDevice
    let buffer: MTLBuffer
    let format: MTLPixelFormat
    let width: Int
    let height: Int

    init?(device: MetalDevice, width: Int, height: Int, format: MTLPixelFormat) {
        self.device = device
        self.width = width
        self.height = height
        self.format = format

        guard let bytesPerPixel = format.bytesPerPixel,
            let buffer = device.device.makeBuffer(
                length: width * height * bytesPerPixel,
                options: .storageModeShared
            )
        else {
            return nil
        }

        self.buffer = buffer

        MetalStageBuffer.recordCreate()
    }

    deinit {
        buffer.setPurgeableState(.empty)
        buffer.makeAliasable()

        MetalStageBuffer.recordDestroy()
    }

    /// Gets an opaque pointer for the ``MetalStageBuffer`` instance and increases its reference count by one
    /// - Returns: `OpaquePointer` to class instance
    ///
    /// > Note: Use this method when the instance is to be shared via an `OpaquePointer` and needs to be retained. Any
    ///  opaque pointer shared this way needs to be converted into a retained reference again to ensure automatic
    /// deinitialization by the Swift runtime.
    func getRetained() -> OpaquePointer {
        let retained = Unmanaged.passRetained(self).toOpaque()

        return OpaquePointer(retained)
    }

    /// Gets an opaque pointer for the ``MetalStageBuffer`` instance without increasing its reference count
    /// - Returns: `OpaquePointer` to class instance
    func getUnretained() -> OpaquePointer {
        let unretained = Unmanaged.passUnretained(self).toOpaque()

        return OpaquePointer(unretained)
    }
}
