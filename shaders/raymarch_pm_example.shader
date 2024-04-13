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
	float g_flSlices < UiType( Slider ); Default(25.0); UiStep( 1 ); Range(1,64); UiGroup( "Variables,10/20" ); >; // Limit it to a max of 64 slices.
	float g_flSliceDistance < UiType( Slider ); Default(0.15); Range(0.001,4); UiGroup( "Variables,10/21" ); >;
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

	CreateInputTexture2D( TextureHeight, Linear, 8, "None", "_height", "Parallax", Default4( 1.00, 1.00, 1.00, 0.00 ) );
	CreateTexture2DWithoutSampler(g_tHeight) < Channel(R, Box(TextureHeight), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
	float3 g_vColorTint < UiType( Color ); Default3( 1.0, 1.0, 1.0 ); UiGroup( "Color" ); >;

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

	float SimpleRaymarchParallax(float flSlices, float flSliceDistance, float2 vUV, float3 vTangentViewDir, float vInputTex)
	{
		// flSlices Default is 25.0 
		// flSliceDistance Default is 0.15 
	
   		vTangentViewDir = normalize( vTangentViewDir.xyz );

		[loop]
		for(int i = 0; i < flSlices; i++)
		{
			if(vInputTex > 0.1)
			{
				return i;
			}

			vUV.xy += (vTangentViewDir.xyz * flSliceDistance);
			vInputTex = Tex2DS(g_tHeight,TextureFiltering,vUV.xy).x;
		}

		// Raymarch Result
		return vInputTex;	
	}

	float3 SimpleRaymarchParallax2(float flSlices, float flSliceDistance, float2 vUV, float3 vTangentViewDir, float vInputTex)
	{
		// flSlices Default is 25.0 
		// flSliceDistance Default is 0.15 

   		vTangentViewDir = normalize( vTangentViewDir.xyz );

		float3 vResult;

		[loop]
		for(int i = 0; i < flSlices; i++)
		{
			if(vInputTex > 0.1)
			{
				vResult = float3(i,0,0);
				return vResult;
			}

			vUV.xy += (vTangentViewDir * flSliceDistance);
			vInputTex = Tex2DS(g_tHeight,TextureFiltering,vUV.xy).x;
		}

		// Raymarch Result
		return vResult;
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
		float3 vTangentViewDir = GetTangentViewVector(i.vPositionWithOffsetWs.xyz,i.vNormalWs.xyz,i.vTangentUWs.xyz,i.vTangentVWs.xyz);
		float flHeightTex = Tex2DS( g_tHeight, TextureFiltering, vUV).x; //Tex2DS(g_tHeightMap,g_sHeightSampler,vUV.xy).xyzw; // Texture Object

		//	
		// Result 
		//

		m.Albedo = SimpleRaymarchParallax2(g_flSlices,g_flSliceDistance,vUV.xy,vTangentViewDir,flHeightTex);
	
		//m.Emission = float3(Raymarched,Raymarched,Raymarched) * g_vColorTint;
		
		#if S_MODE_TOOLS_VIS
		      m.Albedo = m.Emission;
		      m.Emission = 0;
		#endif 

		return ShadingModelStandard::Shade( i, m );
	}
}
