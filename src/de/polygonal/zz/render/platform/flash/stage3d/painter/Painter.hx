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
package de.polygonal.zz.render.platform.flash.stage3d.painter;

import de.polygonal.core.util.Assert.assert;
import de.polygonal.core.util.ClassUtil;
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalShader;
import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.scene.Visual;
import flash.display3D.Context3D;
import flash.Vector;
import haxe.ds.IntMap;
import de.polygonal.core.util.Assert.assert;

import de.polygonal.zz.render.effect.Effect.*;
import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;

@:keep
@:keepSub
class Painter
{
	var mContext:Context3D;
	var mVertexBuffer:Stage3dVertexBuffer;
	var mIndexBuffer:Stage3dIndexBuffer;
	var mShaderLut:IntMap<AgalShader>;
	var mConstantRegisters = new Vector<Float>();
	var mMaxBatchSize:Int;
	
	var mRenderer:Stage3dRenderer; //used be setTexture only
	var mCurrentFeatureFlags:Int;
	var mCurrentShader:AgalShader;
	
	function new(renderer:Stage3dRenderer, featureFlags:Int)
	{
		mRenderer = renderer;
		mContext = renderer.getRenderTarget().getContext();
		
		mShaderLut = new IntMap<AgalShader>();
		mConstantRegisters = new Vector<Float>();
		
		var flags = PainterFeature.print(featureFlags);
		L.d('creating painter: ${ClassUtil.getUnqualifiedClassName(Type.getClass(this))} [${flags}]', "s3d");
	}
	
	public function free()
	{
		if (mVertexBuffer != null)
		{
			mVertexBuffer.free();
			mVertexBuffer = null;
		}
		
		if (mIndexBuffer != null)
		{
			mIndexBuffer.free();
			mIndexBuffer = null;
		}
		
		if (mCurrentShader != null)
		{
			mCurrentShader.free();
			mCurrentShader = null;
		}
	}
	
	public function draw(renderer:Stage3dRenderer, ?visual:Visual, ?batch:ArrayList<Visual>, min = -1, max = -1)
	{
		throw "override for implementation";
	}
	
	public function bind()
	{
		mCurrentFeatureFlags = 0;
		
		#if (verbose == "extra")
		L.d("binding vertex buffer", "s3d");
		#end
		
		mVertexBuffer.bind();
	}
	
	public function unbind()
	{
		#if (verbose == "extra")
		L.d("unbinding vertex buffer", "s3d");
		#end
		
		mVertexBuffer.unbind();
	}
	
	inline function setShader(featureFlags:Int)
	{
		if (featureFlags != mCurrentFeatureFlags)
		{
			mCurrentFeatureFlags = featureFlags;
			mCurrentShader = mShaderLut.get(featureFlags);
			assert(mCurrentShader != null, "no AGAL shader registered");
			mCurrentShader.bindProgram();
			
			#if (verbose == "extra")
			L.d('changed shader, supported features: ${formatFeatures(featureFlags)}', "s3d");
			#end
		}
	}
	
	function formatFeatures(flags:Int):String
	{
		var a = [];
		if (flags & PAINTER_FEATURE_TEXTURE > 0) a.push("texture");
		if (flags & PAINTER_FEATURE_TEXTURE_PMA  > 0) a.push("texture-pma");
		if (flags & PAINTER_FEATURE_COLOR > 0) a.push("color");
		if (flags & PAINTER_FEATURE_ALPHA  > 0) a.push("alpha");
		if (flags & PAINTER_FEATURE_COLOR_TRANSFORM  > 0) a.push("color-transform");
		if (flags & PAINTER_FEATURE_BATCHING  > 0) a.push("batching");
		return a.join(",");
	}
}