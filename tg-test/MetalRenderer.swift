//
//  MetalRenderer.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-24.
//

import Foundation
import MetalKit

// MARK: - MetalRenderer
class MetalRenderer {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var metalLayer: CAMetalLayer!
    private var textureCache: CVMetalTextureCache?
    private var pipelineState: MTLRenderPipelineState?

    
    init(view: UIView) {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device.makeCommandQueue()
        setupMetalLayer(for: view)
        setupPipelineState()
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }
    
    private func setupMetalLayer(for view: UIView) {
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.bounds
        view.layer.addSublayer(metalLayer)
    }
    
    private func setupPipelineState() {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = device.makeDefaultLibrary()?.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = device.makeDefaultLibrary()?.makeFunction(name: "fragment_main")
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func render(pixelBuffer: CVPixelBuffer) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let textureCache = textureCache,
              let pipelineState = pipelineState else { return }
        
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &cvTexture)
        
        if let cvTexture = cvTexture, let texture = CVMetalTextureGetTexture(cvTexture),
           let drawable = metalLayer.nextDrawable() {
            
            let passDescriptor = MTLRenderPassDescriptor()
            passDescriptor.colorAttachments[0].texture = drawable.texture
            passDescriptor.colorAttachments[0].loadAction = .clear
            passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
            passDescriptor.colorAttachments[0].storeAction = .store
            
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setFragmentTexture(texture, index: 0)
                renderEncoder.endEncoding()
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
