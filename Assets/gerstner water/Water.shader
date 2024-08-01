Shader "Custom/Water"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        [Normal]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Range(0,1)) = 1
 
		_WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (1,0,0.5,1)
        _WaveB ("Wave B", Vector) = (0,1,0.25,2)
        _WaveC ("Wave C", Vector) = (1,1,0.15,1)
        _Speed ("Speed", Float) = 1
        
        _IntersectionThreshold("Intersection Threshold", Range(1,5)) = 1
        _BlurAmount("Blur Amount", Float) = 3
    }
    SubShader
    {
        GrabPass 
        {
        }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert addshadow  alpha:premul

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _NormalMap;
        sampler2D _GrabTexture, _CameraDepthTexture;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_NormalMap;
            float4 GrabTexUV : TEXCOORD;
            float3 viewDir;
            float4 screenPos;
        };

        half _Glossiness;
        fixed4 _Color;

        float4 _WaveA, _WaveB, _WaveC;
        float _Speed;
        
        float3 GerstnerWave(float4 wave, float3 vertPos, inout float3 tangent, inout float3 binormal) 
        {
            float waveHeight = wave.z;
            float waveLength = wave.w;
            float k = 2 * UNITY_PI / waveLength;
            float c = sqrt(9.8 / k) * _Speed;
            float2 d = normalize(wave.xy);
            float f = k * (dot(d, vertPos.xz) - _Time.y * c);
            float a = waveHeight / k;
 
 
            tangent += float3(
                 -d.x * d.x * (waveHeight * sin(f)),
                 d.x * (waveHeight * cos(f)), 
                 -d.x * d.y * (waveHeight * sin(f))
                 );
 
            binormal += float3(
                 -d.x * d.y * (waveHeight * sin(f)),
                 d.y * (waveHeight * cos(f)), 
                 -d.y * d.y * (waveHeight * sin(f))
                 );

            return float3(
                d.x * (a * cos(f)),
                a * sin(f),
                d.y * (a * cos(f))
            );
        }

        void vert(inout appdata_full vertexData, out Input IN) 
        {
            //grab pass
            UNITY_INITIALIZE_OUTPUT(Input, IN);
            float4 hpos = UnityObjectToClipPos(vertexData.vertex);
            IN.GrabTexUV = ComputeGrabScreenPos(hpos);

            //waves
           float3 gridPoint = vertexData.vertex.xyz;
           float3 tangent = float3(1,0,0);
           float3 binormal = float3(0,0,1);
           float3 vertPos = gridPoint;
           vertPos += GerstnerWave(_WaveA, gridPoint, tangent, binormal);
           vertPos += GerstnerWave(_WaveB, gridPoint, tangent, binormal);
           vertPos += GerstnerWave(_WaveC, gridPoint, tangent, binormal);
           float3 normal = normalize(cross(binormal, tangent));
           vertexData.vertex.xyz = vertPos; 
           vertexData.normal = normal;
            
        }

        float _NormalIntensity;
        float _IntersectionThreshold;
        float _BlurAmount;
        int _Horizontal;

        float4 blur (float4 GrabTexUV)
        {
            float2 texelSize = float2(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y);

            fixed4 col0 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(GrabTexUV.xy, GrabTexUV.zw))) * 0.3;
            
            float2 uv = GrabTexUV.xy + (float2(2,0) * texelSize * _BlurAmount);
            fixed4 col1 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(uv, GrabTexUV.zw))) * 0.1167;
            
            uv = GrabTexUV.xy + (float2(-2,0) * texelSize * _BlurAmount);
            fixed4 col2 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(uv, GrabTexUV.zw))) * 0.1167;
            
            uv = GrabTexUV.xy + (float2(1,2) * texelSize * _BlurAmount);
            fixed4 col3 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(uv, GrabTexUV.zw))) * 0.1167;
            
            uv = GrabTexUV.xy + (float2(1,-2) * texelSize * _BlurAmount);
            fixed4 col4 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(uv, GrabTexUV.zw))) * 0.1167;
            
            uv = GrabTexUV.xy + (float2(-1,2) * texelSize * _BlurAmount);
            fixed4 col5 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(uv, GrabTexUV.zw))) * 0.1167;
            
            uv = GrabTexUV.xy + (float2(-1,-2) * texelSize * _BlurAmount);
            fixed4 col6 = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(uv, GrabTexUV.zw))) * 0.1167;
            
            return saturate(col0 + col1 + col2 + col3 + col4 + col5 + col6);
        }
        
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = _Color;
            float3 blurredGrab = blur(IN.GrabTexUV).rgb * c;
            float4 bg = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(float4(IN.GrabTexUV.xy, IN.GrabTexUV.zw))) * c;
            float fresnel = pow(1.0 - saturate(dot(normalize(o.Normal), normalize(IN.viewDir))), 0.75);
            o.Albedo = lerp(blurredGrab, c, fresnel);
        
            
            half3 n1 = UnpackScaleNormal(tex2D(_NormalMap, IN.uv_NormalMap + (_Time.y * (fixed2(1, 0.7) * 0.05)) ),
             _NormalIntensity );
            half3 n2 = UnpackScaleNormal(tex2D(_NormalMap, IN.uv_NormalMap + (_Time.y * (fixed2(0.7, -0.5) * 0.025)) ),
            _NormalIntensity * 0.75);
            o.Normal = BlendNormals(n1,n2);

            o.Smoothness = _Glossiness;

            //fade at intersection
            float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UNITY_PROJ_COORD(screenUV));
            float linearDepth = LinearEyeDepth(depth);
            float diff = saturate((linearDepth - IN.screenPos.w)*_IntersectionThreshold);
            o.Alpha = diff;
        }

        ENDCG
    }
    FallBack "Diffuse"
}
