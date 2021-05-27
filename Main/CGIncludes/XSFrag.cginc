float4 frag (
    #if defined(Geometry)
        g2f i
    #else
        VertexOutput i
    #endif
    , uint facing : SV_IsFrontFace
    ) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    TextureUV t = (TextureUV)0; // Populate UVs
    if(_TilingMode != 1) { InitializeTextureUVs(i, t); } else { InitializeTextureUVsMerged(i, t); };

    #ifdef UNITY_PASS_SHADOWCASTER
        XSLighting o = (XSLighting)0; //Populate Lighting Struct, but only with important shadowcaster stuff!
        o.albedo = UNITY_SAMPLE_TEX2D(_MainTex, t.albedoUV) * _Color;
        o.clipMap = tex2Dlod(_ClipMask, float4(t.clipMapUV, 0, 0));
        o.dissolveMask = UNITY_SAMPLE_TEX2D_SAMPLER(_DissolveTexture, _MainTex, t.dissolveUV * _DissolveLayer1Scale + (_Time.y * _DissolveLayer1Speed));
        o.dissolveMaskSecondLayer = UNITY_SAMPLE_TEX2D_SAMPLER(_DissolveTexture, _MainTex, t.dissolveUV * _DissolveLayer2Scale + (_Time.y * _DissolveLayer2Speed));

        o.worldPos = i.worldPos;
        o.screenUV = calcScreenUVs(i.screenPos);
        o.screenPos = i.screenPos;
        o.objPos = i.objPos;

        float alpha = o.albedo.a;
        calcAlpha(o, alpha);
        calcDissolve(o, o.albedo.rgb);
        return alpha;
    #else
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);

        // fix for rare bug where light atten is 0 when there is no directional light in the scene
        #ifdef UNITY_PASS_FORWARDBASE
            if(all(_LightColor0.rgb == 0.0))
                attenuation = 1.0;
        #endif

        #if defined(DIRECTIONAL)
            half sharp = _ShadowSharpness * 0.5;
            attenuation = smoothstep(sharp, 1-sharp, attenuation); //Converge at the center line
        #endif

        bool face = facing > 0; // True if on front face, False if on back face
        if (!face) // Invert Normals based on face
        {
            if(i.color.a > 0.99) { discard; }//Discard outlines front face always. This way cull off and outlines can be enabled.

            i.ntb[0] = -i.ntb[0];
            i.ntb[1] = -i.ntb[1];
            i.ntb[2] = -i.ntb[2];
        }

        XSLighting o = (XSLighting)0; //Populate Lighting Struct
        o.albedo = UNITY_SAMPLE_TEX2D(_MainTex, t.albedoUV) * _Color * lerp(1, float4(i.color.rgb, 1), _VertexColorAlbedo);
        o.specularMap = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecularMap, _MainTex, t.specularMapUV);
        o.metallicGlossMap = UNITY_SAMPLE_TEX2D_SAMPLER(_MetallicGlossMap, _MainTex, t.metallicGlossMapUV);
        o.detailMask = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailMask, _MainTex, t.detailMaskUV);
        o.normalMap = UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, t.normalMapUV);
        o.detailNormal = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailNormalMap, _MainTex, t.detailNormalUV);
        o.thickness = UNITY_SAMPLE_TEX2D_SAMPLER(_ThicknessMap, _MainTex, t.thicknessMapUV);
        o.occlusion = tex2D(_OcclusionMap, t.occlusionUV);
        o.reflectivityMask = UNITY_SAMPLE_TEX2D_SAMPLER(_ReflectivityMask, _MainTex, t.reflectivityMaskUV) * _Reflectivity;
        o.emissionMap = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, t.emissionMapUV);
        o.emissionMap2 = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap2, _MainTex, t.emissionMapUV);
        o.rampMask = UNITY_SAMPLE_TEX2D_SAMPLER(_RampSelectionMask, _MainTex, i.uv); // This texture doesn't need to ever be on a second uv channel, and doesn't need tiling, convince me otherwise.
        o.hsvMask = UNITY_SAMPLE_TEX2D_SAMPLER(_HSVMask, _MainTex, t.albedoUV);
        o.clipMap = tex2Dlod(_ClipMask, float4(t.clipMapUV, 0, 0));
        o.dissolveMask = UNITY_SAMPLE_TEX2D_SAMPLER(_DissolveTexture, _MainTex, t.dissolveUV * _DissolveLayer1Scale + (_Time.y * _DissolveLayer1Speed));
        o.dissolveMaskSecondLayer = UNITY_SAMPLE_TEX2D_SAMPLER(_DissolveTexture, _MainTex, t.dissolveUV * _DissolveLayer2Scale + (_Time.y * _DissolveLayer2Speed));

        o.diffuseColor = o.albedo.rgb; //Store this to separate the texture color and diffuse color for later.
        o.attenuation = attenuation;
        o.normal = i.ntb[0];
        o.tangent = i.ntb[1];
        o.bitangent = i.ntb[2];
        o.worldPos = i.worldPos;
        o.color = i.color.rgb;
        o.isOutline = i.color.a;
        o.screenUV = calcScreenUVs(i.screenPos);
        o.screenPos = i.screenPos;
        o.objPos = i.objPos;

        float3 vertex3Pos = mul(unity_WorldToObject, i.worldPos);
        float time1 = _Time.y * _DissolveLayer1Speed;
        float time2 = _Time.y * _DissolveLayer2Speed;
        float time3 = _Time.y * _DissolveLayer2Speed;

        o.noise1 = voronoi(float3((vertex3Pos.x + (time1)) * (_SimplexScale.x * _DissolveLayer1Scale), (vertex3Pos.y + (time1 * -2)) * (_SimplexScale.y * _DissolveLayer1Scale), (vertex3Pos.z + (time1 * 1.5)) * (_SimplexScale.z * _DissolveLayer1Scale)));
        o.noise2 = voronoi(float3((vertex3Pos.x + (time2 * 1.5)) * (_SimplexScale.x * _DissolveLayer2Scale), (vertex3Pos.y + (time2)) * (_SimplexScale.y * _DissolveLayer2Scale), (vertex3Pos.z + (time2 * 2)) * (_SimplexScale.z * _DissolveLayer2Scale)));
        o.noise3 = voronoi(float3((vertex3Pos.x + (time3 * .7)) * (_SimplexScale.x * _DissolveLayer2Scale * .7), (vertex3Pos.y + (time3 * .5)) * (_SimplexScale.y * _DissolveLayer2Scale * .7), (vertex3Pos.z + (time3 * 2.7)) * (_SimplexScale.z * _DissolveLayer2Scale * .7)));

        float4 col = BRDF_XSLighting(o,t);
        float alpha = o.albedo.a;
        calcAlpha(o, alpha);
        calcDissolve(o, col.rgb);
        UNITY_APPLY_FOG(i.fogCoord, col);
        return float4(col.rgb, alpha);
    #endif
}