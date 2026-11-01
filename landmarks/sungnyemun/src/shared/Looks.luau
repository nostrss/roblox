--!strict
-- 숭례문 낮·노을·밤 색조 (core TimeOfDay가 해 높이에 따라 바꾼다).
-- 하늘은 tools/sky_cube.mjs로 구운 큐브맵이다. 노을 하늘의 해 쪽 빛은 ClockTime 17.6의 해 방향에 맞춰 구웠다.
-- 근사: 색 자료 없음. 노을은 주황·보라, 밤은 S15 사진처럼 짙은 남색 하늘. Studio에서 다듬은 값은 여기 옮겨 적는다.
local rgb = Color3.fromRGB

local function sky(bk: number, dn: number, ft: number, lf: number, rt: number, up: number): { [string]: any }
	local id = function(n: number): string
		return `rbxassetid://{n}`
	end
	return {
		SkyboxBk = id(bk), SkyboxDn = id(dn), SkyboxFt = id(ft), SkyboxLf = id(lf), SkyboxRt = id(rt), SkyboxUp = id(up),
	}
end

return {
	day = {
		Sky = sky(127880672906473, 85145741487119, 90572582244649, 112905655674416, 135778438348043, 81248762751742),
		Atmosphere = { Density = 0.14, Offset = 0.2, Color = rgb(205, 216, 228), Decay = rgb(120, 140, 170), Glare = 0.1, Haze = 0.6 },
		ColorCorrectionEffect = { TintColor = rgb(255, 252, 246), Saturation = 0.06, Contrast = 0.06, Brightness = 0 },
		BloomEffect = { Intensity = 0.35, Size = 24, Threshold = 2 },
		SunRaysEffect = { Intensity = 0.03, Spread = 0.3 },
		Lighting = { Brightness = 2.6, OutdoorAmbient = rgb(112, 118, 128), Ambient = rgb(70, 70, 72), ColorShift_Top = rgb(255, 244, 226), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1 },
	},
	sunset = {
		Sky = sky(89508213159277, 131069333135660, 98563339719199, 116274250898115, 80282693899109, 125175301438133),
		Atmosphere = { Density = 0.16, Offset = 0.2, Color = rgb(255, 196, 150), Decay = rgb(170, 120, 130), Glare = 0.3, Haze = 0.5 },
		ColorCorrectionEffect = { TintColor = rgb(255, 240, 226), Saturation = 0.02, Contrast = 0.04, Brightness = 0 },
		BloomEffect = { Intensity = 0.7, Size = 32, Threshold = 1.6 },
		SunRaysEffect = { Intensity = 0.14, Spread = 0.5 },
		Lighting = { Brightness = 2.8, OutdoorAmbient = rgb(118, 100, 112), Ambient = rgb(70, 56, 60), ColorShift_Top = rgb(255, 176, 104), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1 },
	},
	night = {
		Sky = sky(134621696452368, 114576810942815, 71280896274677, 113512236693112, 72406569135805, 108349560716143),
		Atmosphere = { Density = 0.14, Offset = 0.2, Color = rgb(58, 62, 96), Decay = rgb(30, 32, 66), Glare = 0, Haze = 0.6 },
		ColorCorrectionEffect = { TintColor = rgb(226, 230, 255), Saturation = 0, Contrast = 0.08, Brightness = 0.02 },
		BloomEffect = { Intensity = 0.9, Size = 24, Threshold = 1.3 },
		SunRaysEffect = { Intensity = 0 },
		Lighting = { Brightness = 1.4, OutdoorAmbient = rgb(84, 92, 124), Ambient = rgb(60, 62, 78), ColorShift_Top = rgb(160, 180, 230), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.8 },
	},
}
