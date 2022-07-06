import UIKit
import VideoToolbox

@available(iOS 14.0, *)
extension UIImage {
    
    public func segmentation() -> CGImage? {
        guard var cgImage = self.coarseSegmentation() else {
            return nil
        }
//        여기서 outputWidth로 크기 정하기
        let outputWidth:CGFloat = 512
        let outputSize = CGSize(width: outputWidth, height: outputWidth * (self.size.height / self.size.width)) //512 683
        let resizeImg = UIImage(cgImage: cgImage).resize(size: outputSize)!
        let ciImg = CIImage(cgImage: resizeImg.cgImage!)
        let smoothFilter = SmoothFilter.init()
        smoothFilter.inputImage = ciImg
 
        let outputImage = smoothFilter.outputImage!
        let ciContext = CIContext(options: nil)
        cgImage = ciContext.createCGImage(outputImage, from: ciImg.extent)!
        return cgImage
    }
    
    public func coarseSegmentation() -> CGImage? {
        let start=Date()

//        let model = try? DeeplabV3_2.init() // Deeplab_2
        let model = UNet_2.init()   // UNet2

        let init_fin=Date()
        print("init fin")
        print("실행 시간 :", (-start.timeIntervalSinceNow))
        
//        input size 맞춰주기
        let pixBuf = self.pixelBuffer(width: 512, height: 512)  // Deeplab_2, UNet2
        
        guard let output = try? model.prediction(input: pixBuf!) else {    // Deeplab_2, UNet2
            return nil
        }
        
        let pred_fin = Date()
        print("pred fin")
        print("실행 시간 :", (-init_fin.timeIntervalSinceNow))

//        let shape = output.var_787.shape // Deeplab_2, shape: [1, 2, 512, 512]
        let shape = output.var_449.shape   // UNet2
        
        let (d,w,h) = (Int(truncating: shape[1]), Int(truncating: shape[2]), Int(truncating: shape[3]))  // Deeplab_2, UNet2
//        print(d, w, h)    // Deeplab_2: 2 512 512

        let pageSize = w*h
        var res:Array<Int> = []
        var pageIndexs:Array<Int> = []
        for i in 0..<d {
            pageIndexs.append(pageSize * i)
        }
 
        func argmax(arr:Array<Int>) -> Int{
            precondition(arr.count > 0)
            var maxValue = arr[0]
            var maxValueIndex = 0
            for i in 1..<arr.count {
                if arr[i] > maxValue {
                    maxValue = arr[i]
                    maxValueIndex = i
                }
            }
            return maxValueIndex
        }
        
        for i in 0..<w {    //w: width
            for j in 0..<h {    //h: height
                var itemArr:Array<Int> = []
                let pageOffset = i * w + j
                for k in 0..<d {
                    let padding = pageIndexs[k]
//                    itemArr.append(Int(truncating: (output.var_787[padding + pageOffset]))) // Deeplab_2
                    itemArr.append(Int(truncating: (output.var_449[padding + pageOffset])))   // UNet2
                }
                let type = argmax(arr: itemArr)
                res.append(type)
            }
        }
        
        let bytesPerComponent = MemoryLayout<UInt8>.size
        let bytesPerPixel = bytesPerComponent * 4
        let length = pageSize * bytesPerPixel
        var data = Data(count: length)
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
            var pointer = bytes
//            [background, teeth] 중 [teeth]
            let reserve = [1]
            for pix in res{
                let v:UInt8 = reserve.contains(pix) ? 255 : 0
                for _ in 0...3 {
                    pointer.pointee = v
                    pointer += 1
                }
            }
        }
        
//        let loop_fin = Date()
        print("loop fin")
        print("실행 시간 :", (-pred_fin.timeIntervalSinceNow))

//    https://developer.apple.com/documentation/coregraphics/cgimage/1455149-init 참고
        let provider: CGDataProvider = CGDataProvider(data: data as CFData)!
        let cgimg = CGImage(
            width: w,
            height: h,
            bitsPerComponent: bytesPerComponent * 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerPixel * w,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider:provider,
            decode: nil,
            shouldInterpolate: false,
            intent: CGColorRenderingIntent.defaultIntent
            )
        return cgimg
    }
}

extension UIImage {
    
  public func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    return pixelBuffer(width: width, height: height,
                       pixelFormatType: kCVPixelFormatType_32ARGB,
                       colorSpace: CGColorSpaceCreateDeviceRGB(),
                       alphaInfo: .noneSkipFirst)
  }
 
  func pixelBuffer(width: Int, height: Int, pixelFormatType: OSType,
                   colorSpace: CGColorSpace, alphaInfo: CGImageAlphaInfo) -> CVPixelBuffer? {
    var maybePixelBuffer: CVPixelBuffer?
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     width,
                                     height,
                                     pixelFormatType,
                                     attrs as CFDictionary,
                                     &maybePixelBuffer)

    guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)

    guard let context = CGContext(data: pixelData,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                  space: colorSpace,
                                  bitmapInfo: alphaInfo.rawValue)
    else {
      return nil
    }

    UIGraphicsPushContext(context)
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    return pixelBuffer
  }
}

extension UIImage {
    
    func resize(size: CGSize!) -> UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        self.draw(in:rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

fileprivate class SmoothFilter : CIFilter {
    
    private let kernel: CIColorKernel
    var inputImage: CIImage?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init() {
        let kernelStr = """
            kernel vec4 myColor(__sample source) {
                float maskValue = smoothstep(0.3, 0.5, source.r);
                return vec4(maskValue,maskValue,maskValue,1.0);
            }
        """
        let kernels = CIColorKernel.makeKernels(source:kernelStr)!
        kernel = kernels[0] as! CIColorKernel
        super.init()
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else {return nil}
        let blurFilter = CIFilter.init(name: "CIGaussianBlur")!
        blurFilter.setDefaults()
        blurFilter.setValue(inputImage.extent.width / 90.0, forKey: kCIInputRadiusKey)
        blurFilter.setValue(inputImage, forKey: kCIInputImageKey)
        let bluredImage = blurFilter.value(forKey:kCIOutputImageKey) as! CIImage
        return kernel.apply(extent: bluredImage.extent, arguments: [bluredImage])
    }
}
