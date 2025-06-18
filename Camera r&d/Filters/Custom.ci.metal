//
//  Custom.ci.metal
//  Camera r&d
//
//  Created by Appnap WS05 on 6/16/25.
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" { namespace coreimage {
    // write your methods
    float4 makeLeftSideTransparent(sampler src, float maximumLeftPositionX) {
        float2 position = src.coord();
        if (position.x <= maximumLeftPositionX) {
            return float4(0,0,0,0);
            
        } else {
            return src.sample(position);
        }
    }
}}



extern "C" { namespace coreimage {
    
    float2 normalizeCoord(float2 coord, float2 size) {
        return 2.0 * coord / size - 1.0;
    }

    float2 denormalizeCoord(float2 coord, float2 size) {
        return (coord + 1.0) * 0.5 * size;
    }

    float2 polarPixellate(float2 coord, float2 size, float2 center, float2 pixelSize) {
        float2 normCoord = normalizeCoord(coord, size);
        float2 normCenter = 2.0 * center - 1.0;
        normCoord -= normCenter;
        
        float r = length(normCoord);
        float phi = atan2(normCoord.y, normCoord.x);
        
        r = r - fmod(r, pixelSize.x) + 0.03;
        phi = phi - fmod(phi, pixelSize.y);
        
        float2 newCoord = float2(r * cos(phi), r * sin(phi));
        newCoord += normCenter;
        
        return denormalizeCoord(newCoord, size);
    }

    float4 polarPixellateKernel(sampler src, float2 pixelSize, float2 center) {
        float2 coord = samplerCoord(src);
        float2 size = float2(samplerSize(src));
        
        float2 mappedCoord = polarPixellate(coord, size, center, pixelSize);
        return sample(src, mappedCoord);
    }

}}


extern "C" namespace coreimage {

    float4 polkaDotKernel(sampler inputSampler,
                          float2 destCoord,
                          float2 sampleDivisor,
                          float dotScaling)
    {
        float2 texSize = float2(samplerSize(inputSampler));
        float aspectRatio = texSize.y / texSize.x;

        float2 normCoord = destCoord / texSize;
        
        float2 samplePos = normCoord - fmod(normCoord, sampleDivisor) + 0.5 * sampleDivisor;
        float2 textureCoordinateToUse = float2(normCoord.x, normCoord.y * aspectRatio + 0.5 - 0.5 * aspectRatio);
        float2 adjustedSamplePos = float2(samplePos.x, samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio);

        float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
        float check = step(distanceFromSamplePoint, (sampleDivisor.x * 0.5) * dotScaling);

        float4 color = inputSampler.sample(samplePos * texSize);
        color.rgb *= check;

        return color;
    }

}
