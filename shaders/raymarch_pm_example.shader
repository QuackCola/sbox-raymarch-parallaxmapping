//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
	Description = "Basic Parallax Mapping Shader Example ";
}

MODES
{
    VrForward();                                               // Indicates this shader will be used for main rendering
    ToolsVis( S_MODE_TOOLS_VIS );                              // Ability to see in the editor
    ToolsWireframe("vr_tools_wireframe.shader");               // Allows for mat_wireframe to work
    ToolsShadingComplexity("tools_shading_complexity.shader"); // Shows how expensive drawing is in debug view
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
FEATURES
{
    #include "common/features.hlsl"
}

//=========================================================================================================================
COMMON
{
	#include "common/shared.hlsl"
	//#define S_UNLIT 1
	#define S_UV2 1
	#define VS_INPUT_HAS_TANGENT_BASIS 1
	#define PS_INPUT_HAS_TANGENT_BASIS 1
	#define CUSTOM_MATERIAL_INPUTS

	//
	// Parameters
	//
	float g_vSlices < UiType( Slider ); Default(25.0); Range(1,64); UiGroup( "Variables,10/20" ); >; // Limit it to a max of 64 slices.
	float g_vSliceDistance < UiType( Slider ); Default(0.15); Range(0.001,4); UiGroup( "Variables,10/21" ); >;
	float g_vTexCoordScale < UiType( Slider ); UiStep( 1 ); Default(1); Range(1,8); UiGroup( "Variables,10/21" ); >;
	float g_vEmissionStrength < UiType(Slider); Default (0.1); Range(0.1,8); UiGroup("Variables,10/20"); >;
}

//=========================================================================================================================

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

//=========================================================================================================================

struct PixelInput
{
	#include "common/pixelinput.hlsl"
	float3 vPositionOs : TEXCOORD14;
	float3 vNormalOs : TEXCOORD15;
	float4 vTangentUOs_flTangentVSign : TANGENT	< Semantic( TangentU_SignV ); >;

};

//=========================================================================================================================

VS
{
	#include "common/vertex.hlsl"

	PixelInput MainVs( VertexInput v )
	{
		PixelInput i = ProcessVertex( v );
		i.vPositionOs = v.vPositionOs.xyz;
		//i.vColor = v.vColor;

		VS_DecodeObjectSpaceNormalAndTangent( v, i.vNormalOs, i.vTangentUOs_flTangentVSign );

		return FinalizeVertex( i );
	}
}

//=========================================================================================================================

PS
{
	//
	// Includes
	//
    #include "common/pixel.hlsl"
	
	// -------------------------------------------------------------------------------------------------------------------------------------------------------------

	//
	// Parameters
	//
	SamplerState g_sHeightSampler< Filter( ANISO ); AddressU( WRAP ); AddressV( WRAP ); >;
	CreateInputTexture2D( Height, Srgb, 8, "None", "_height", "Height,0/,0/0", Default4( 1.00, 1.00, 1.00, 1.00 ) );
	Texture2D g_tHeightMap < Channel( RGB, Box( Height ), Srgb ); OutputFormat( DXT5 ); SrgbRead( True ); >;

	// -------------------------------------------------------------------------------------------------------------------------------------------------------------

	//
	// Functions
	//

	// TODO : Figure out what's causing the warping when the camera ( aka player ) gets close to the effect surface.

	float3 GetTangentViewVector( float3 vPositionWithOffsetWs, float3 vNormalWs, float3 vTangentUWs, float3 vTangentVWs)
	{
		float3 vPositionWs = vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
        float3 vCameraToPositionDirWs = CalculateCameraToPositionDirWs( vPositionWs.xyz );
        vNormalWs = normalize( vNormalWs.xyz );
       	float3 vTangentViewVector = Vec3WsToTs( vCameraToPositionDirWs.xyz, vNormalWs.xyz, vTangentUWs.xyz, vTangentVWs.xyz );
		
		// Result
		return vTangentViewVector.xyz;
	}
 
	float3 ParallaxRaymarching(float2 vUV, float3 vViewDir, float3 vInputTex)
	{
		//float vRaystep = vViewDir * -1;
		// g_vSlices is the number of slices. Default is 25.0 
		// g_vSliceDistance is the distance between each slice. Default is 0.15 

		//  Normalize the incoming view vector to avoid artifacts:
		//   vView = normalize( vView ); 
   		vViewDir = normalize( vViewDir.xyz );

		[loop]
		for(int i = 0; i < g_vSlices; i++)
		{
			if(vInputTex.r > 0.1 && vInputTex.g > 0.1 && vInputTex.b > 0.1)
			{
				// red value will increase with each slice.
				return float3(i,0,0);

				// greyscale value will increase with each slice
				//return float3(i,i,i);
			}

			vUV.xy += (vViewDir.xyz * g_vSliceDistance);
			vInputTex = Tex2DS(g_tHeightMap,g_sHeightSampler,vUV.xy).xyz;
		}

		// Raymarch Result
		return vInputTex;	
	}

	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		Material m = Material::Init();
		m.Albedo = float3( 0, 0, 0 );
		m.Normal = TransformNormal( float3( 0, 0, 1 ), i.vNormalWs, i.vTangentUWs, i.vTangentVWs );
		m.Roughness = 1;
		m.Metalness = 0;
		m.AmbientOcclusion = 0;
		m.TintMask = 1;
		m.Opacity = 1;
		m.Emission = float3( 0, 0, 0 );
		m.Transmission = 0;

		float2 vUV = i.vTextureCoords.xy * g_vTexCoordScale;
		float4 vInputTex = Tex2DS(g_tHeightMap,g_sHeightSampler,vUV.xy).xyzw; // Texture Object
		float3 vTangentViewDir = GetTangentViewVector(i.vPositionWithOffsetWs.xyz,i.vNormalWs.xyz,i.vTangentUWs.xyz,i.vTangentVWs.xyz);

		//	
		// Result 
		//
		m.Emission = ParallaxRaymarching(vUV.xy,vTangentViewDir.xyz,vInputTex.xyz) * g_vEmissionStrength;

		// make sure we are able to see the result in the editor when in fullbright or ingame when mat_fullbright is set to 1.
		#if S_MODE_TOOLS_VIS
		      m.Albedo = m.Emission;
		      m.Emission = 0;
		#endif

		return ShadingModelStandard::Shade( i, m );
	}
}
