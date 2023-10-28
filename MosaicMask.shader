Shader "Unlit/MosaicMask"
{
	Properties
	{
		_MinPxX("最小ピクセルサイズX",int) = 4
		_MinPxY("最小ピクセルサイズY",int) = 4
		[Toggle] _LinkEnable ("AudioLink対応", int) = 1
		[IntRange] _AudioLinkBandX("帯域X", Range(0, 3)) = 0
		[IntRange] _AudioLinkBandY("帯域Y", Range(0, 3)) = 0
		_Color("色のオーバーレイ", Color) = (1,1,1,1)
		_Texture("テクスチャ", 2D) = "white" {}
		_MaskTexture("マスクテクスチャ", 2D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Geometry" }

		ZTest LEqual
		Cull Off

		LOD 100

		Pass
		{
			Name "MosaicMask"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#include "UnityCG.cginc"

			sampler2D _Texture;
			float4 _Texture_ST;
			sampler2D _MaskTexture;
			float4 _MaskTexture_ST;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 mask = tex2D(_MaskTexture, i.uv);
				fixed4 col = tex2D(_Texture, i.uv);
				return col * mask;
			}
			ENDCG
		}

		
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }

		GrabPass{"_MosaicLinkBGTexture"}

		Pass
		{
			Name "MosaicLink"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#include "UnityCG.cginc"
			#include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

			sampler2D _MosaicLinkBGTexture;
			float4 _MosaicLinkBGTexture_ST;
			bool _LinkEnable;
			int _MinPxX;
			int _MinPxY;
			int _AudioLinkBandX;
			int _AudioLinkBandY;
			fixed4 _Color;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 uv : TEXCOORD0;
				float4 grabPos: TEXCOORD1;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = ComputeScreenPos(o.vertex);
				o.grabPos = ComputeGrabScreenPos(o.vertex);

				return o;
			}

			float rand(float2 co) {
				return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
			}


			fixed4 frag(v2f i) : SV_Target
			{
				
				_MinPxX = _MinPxX * AudioLinkData(ALPASS_AUDIOLINK + int2(0, _AudioLinkBandX)).r;
				_MinPxX = max(_MinPxX, 1);

				_MinPxY = _MinPxY * AudioLinkData(ALPASS_AUDIOLINK + int2(0, _AudioLinkBandY)).r;
				_MinPxY = max(_MinPxY, 1);
				
				// 1ピクセル当たりの正規化スケール
				float2 pixelSize = 1.0 / (float2)_ScreenParams.xy;

				float mosaicSizeX = pixelSize.x * _MinPxX;
				float mosaicSizeY = pixelSize.y * _MinPxY;
				float2 mosaicSize = float2(mosaicSizeX, mosaicSizeY);

				float2 mosaicSizeFixed = mosaicSize;

				// 正規化スケールに対する長辺の分割数
				float2 divideNum = 1.0 / mosaicSizeFixed;

				fixed2 grabUV = i.grabPos.xy / i.grabPos.w;
				float2 screenUV = i.uv.xy / i.uv.w;
				
				
				#if UNITY_SINGLE_PASS_STEREO
					divideNum.x = divideNum.x * 2;
					mosaicSizeFixed.x = mosaicSizeFixed.x / 2;
				#endif
				
				
				float randomX = rand(64 * floor(screenUV.x * divideNum.x) / divideNum.x);
				float randomWaveX = 0.5 * randomX * sin(_Time.w + randomX * 64 * floor(screenUV.x * divideNum.x) / divideNum.x);

				//床関数使ってピクセル化、中央ピクセルをサンプル
				fixed posUVX = (floor(screenUV.x * divideNum.x) / divideNum.x) + (mosaicSizeFixed.x / 2.0);
				fixed posUVY = (floor(screenUV.y * divideNum.y + randomWaveX) / divideNum.y) + (-1 * randomWaveX / divideNum.y + mosaicSizeFixed.y / 2.0);
				fixed2 posUV = fixed2(posUVX, posUVY);

				fixed4 grabColor = tex2D(_MosaicLinkBGTexture, grabUV);
				fixed4 posColor = tex2D(_MosaicLinkBGTexture, posUV) * _Color;
				fixed4 blendedColor = lerp(grabColor, posColor, _Color.a);

				fixed4 finalColor = fixed4(blendedColor.rgb, 1.0);
				return finalColor;
			}
			ENDCG
		}
		
		
	}
		FallBack "Unlit/Color"
}
