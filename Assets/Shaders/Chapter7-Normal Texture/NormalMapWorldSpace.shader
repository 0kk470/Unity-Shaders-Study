﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unity Shader Book/Chapter 7/NormalMapInTangentSpace"
{
	Properties
	{
	    _Color("Color",Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" {}
        _BumpMap("Normal Map",2D) = "bump"{} //凹凸映射
        _BumpScale("Bump Scale",Range(-2.0,2.0)) = 1 //控制凹凸程度
        _Specular("Specular",Color) = (1,1,1,1)
        _Gloss("Gloss",Range(8.0,256)) = 20

	}
	SubShader
	{
		Tags { "LightMode"="ForwardBase" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal:NORMAL;
				float4 tangent:TANGENT;  //the tangent direction of the vertex
				float4 texcoord : TEXCOORD0;
			};

			struct v2f
			{
				float4 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 TtoW0:TEXCOORD1;
				float4 TtoW1:TEXCOORD2;
				float4 TtoW2:TEXCOORD3;
			};

			fixed4 _Color;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float  _BumpScale;
			fixed4 _Specular;
			float  _Gloss;

			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				//Offset and Scale
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				float3 worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				fixed3 worldBinormal = cross(worldNormal,worldTangent) * v.tangent.w;

				//Compute the matrix that transform direction from tangent space to world space
				//put the world pos in w component for optimization
				o.TtoW0 = float4(worldTangent.x,worldBinormal.x,worldNormal.x,worldPos.x);
				o.TtoW1 = float4(worldTangent.y,worldBinormal.y,worldNormal.x,worldPos.y);
				o.TtoW2 = float4(worldTangent.z,worldBinormal.z,worldNormal.x,worldPos.z);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//Get the pos in world space
				float3 worldPos = float3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w);
				//Compute the light and view dir in world space
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

				//Get the normal in tangent space
				fixed3 bump = UnpackNormal(tex2D(_BumpMap,i.uv.zw));
				bump.xy *= _BumpScale;
				bump.z = sqrt(1.0 - saturate(dot(bump.xy,bump.xy)));
				//Transform the normal from tangent space to world space
				bump = normalize(half3(dot(i.TtoW0.xyz,bump),dot(i.TtoW1.xyz,bump),dot(i.TtoW2.xyz,bump)));

				fixed3 albedo = tex2D(_MainTex,i.uv).rgb * _Color.rgb;

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT * albedo;

				fixed3 diffuse = _LightColor0.rgb * albedo * max(0,dot(bump , lightDir));

				fixed3 halfDir = normalize(lightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0,dot(bump,halfDir)),_Gloss);

				return fixed4(ambient + diffuse + specular,1.0);
			}
			ENDCG
		}
	}
}
