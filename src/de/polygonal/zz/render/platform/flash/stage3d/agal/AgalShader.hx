/*
Copyright (c) 2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.zz.render.platform.flash.stage3d.agal;

import de.polygonal.zz.render.platform.flash.stage3d.agal.util.AgalMiniAssembler;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dTextureFlag;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dTextureFlag.*;
import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;
import flash.display3D.Program3D;
import flash.display3D.textures.Texture;
import flash.utils.ByteArray;

using de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature;

class AgalShader
{
	var mFeatureFlags:Int;
	var mContext:Context3D;
	var mProgram:Program3D;
	var mVertexShader:ByteArray;
	var mFragmentShader:ByteArray;
	
	public function new(context:Context3D, featureFlags:Int, textureFlags:Int)
	{
		mContext = context;
		mFeatureFlags = featureFlags;
		
		if (textureFlags == 0)
			compileShaders(0);
		else
		{
			assert(textureFlags > 0);
			assert(textureFlags & (MM_NONE | MM_NEAREST | MM_LINEAR) > 0, "mipmap flag missing");
			assert(textureFlags & (FM_NEAREST | FM_LINEAR) > 0, "filtering flag missing");
			assert(textureFlags & (REPEAT_NORMAL | REPEAT_CLAMP) > 0, "repeat flag missing");
			
			compileShaders(textureFlags);
		}
	}
	
	public function free()
	{
		if (mProgram != null)
		{
			mProgram.dispose();
			mProgram = null;
		}
		
		mContext = null;
	}
	
	inline public function bindProgram()
	{
		if (mProgram == null)
		{
			mProgram = mContext.createProgram();
			mProgram.upload(mVertexShader, mFragmentShader);
		}
		
		mContext.setProgram(mProgram);
	}
	
	inline public function bindTexture(samplerIndex:Int, texture:Texture)
	{
		mContext.setTextureAt(samplerIndex, texture);
	}
	
	inline public function unbindTexture(samplerIndex:Int)
	{
		mContext.setTextureAt(samplerIndex, null);
	}
	
	inline public function supportsAlpha():Bool return mFeatureFlags.supportsAlpha();
	
	inline public function supportsColorTransform():Bool return mFeatureFlags.supportsColorTransform();
	
	inline public function supportsTexture():Bool return mFeatureFlags.supportsTexture();
	
	inline public function supportsTexturePremultipliedAlpha():Bool return mFeatureFlags.supportsTexturePremultipliedAlpha();
	
	function compileShaders(textureFlags:Int)
	{
		var assembler = AgalMiniAssembler.instance;
		
		var source;
		
		source = getVertexShader();
		mVertexShader = assembler.assemble(cast Context3DProgramType.VERTEX, source);
		
		source = getFragmentShader();
		if (textureFlags > 0) source = StringTools.replace(source, "TEX_FLAGS", "2d," + Stage3dTextureFlag.print(textureFlags));
		mFragmentShader = assembler.assemble(cast Context3DProgramType.FRAGMENT, source);
	}
	
	function getVertexShader():String return throw "override for implementation";
	
	function getFragmentShader():String return throw "override for implementation";
}