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

import de.polygonal.ds.ArrayList;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalTextureShader;
import de.polygonal.zz.render.platform.flash.stage3d.painter.Painter.*;
import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.scene.Visual;
import de.polygonal.zz.texture.Texture;
import flash.display3D.Context3DProgramType;

@:access(de.polygonal.zz.render.Renderer)
class PainterQuadTexture extends PainterQuad
{
	public function new(renderer:Stage3dRenderer, featureFlags:Int, textureFlags:Int)
	{
		super(renderer, featureFlags);
		
		inline function registerShader(featuresFlags:Int, textureFlags:Int)
			mShaderLut.set(featuresFlags, new AgalTextureShader(mContext, featuresFlags, textureFlags));
		
		registerShader(PAINTER_FEATURE_TEXTURE                            , textureFlags);
		registerShader(PAINTER_FEATURE_TEXTURE     | PAINTER_FEATURE_ALPHA, textureFlags);
		registerShader(PAINTER_FEATURE_TEXTURE_PMA                        , textureFlags);
		registerShader(PAINTER_FEATURE_TEXTURE_PMA | PAINTER_FEATURE_ALPHA, textureFlags);
	}
	
	override public function bind()
	{
		if (mVertexBuffer == null)
		{
			initVertexBuffer(1, [2]);
			initIndexBuffer(1);
		}
		
		super.bind();
	}
	
	override public function unbind() 
	{
		super.unbind();
		
		mCurrentShader.unbindTexture(0);
	}
	
	override public function draw(renderer:Stage3dRenderer, ?visual:Visual, ?batch:ArrayList<Visual>, min = -1, max = -1)
	{
		assert(visual != null);
		
		var cr = mConstantRegisters;
		for (i in 0...3 * 4) cr[i] = 0;
		
		renderer.setGlobalState(visual);
		
		var featureFlags = 0;
		
		var alpha = renderer.currentAlphaMultiplier;
		if (alpha < 1) featureFlags |= PAINTER_FEATURE_ALPHA;
		
		var effect = visual.effect.as(TextureEffect);
		if (effect.texture.isAlphaPremultiplied)
			featureFlags |= PAINTER_FEATURE_TEXTURE_PMA;
		else
			featureFlags |= PAINTER_FEATURE_TEXTURE;
		
		setShader(featureFlags);
		bindTexture(effect.texture);
		
		//setup constants
		var crop = effect.cropRectUv;
		var mvp = renderer.setModelViewProjMatrix(visual.world);
		mvp.m13 = alpha;
		mvp.m23 = 1; //op.zw
		mvp.m31 = crop.w * effect.uvScaleX;
		mvp.m32 = crop.h * effect.uvScaleY;
		mvp.m33 = crop.x + effect.uvOffsetX;
		mvp.m34 = crop.y + effect.uvOffsetY;
		
		/*if (supportsColorTransform)
		{
			var t = e.colorTransform.multiplier;
			if (pma)
			{
				var am = t.a;
				cr[0] = t.r * am * alpha;
				cr[1] = t.g * am * alpha;
				cr[2] = t.b * am * alpha;
				cr[3] = t.a * alpha;
			}
			else
			{
				cr[0] = t.r;
				cr[1] = t.g;
				cr[2] = t.b;
				cr[3] = t.a * alpha;
			}
			
			t = e.colorTransform.offset;
			cr[4] = t.r * (1 / 0xFF);
			cr[5] = t.g * (1 / 0xFF);
			cr[6] = t.b * (1 / 0xFF);
			cr[7] = t.a * (1 / 0xFF);
			
			mContext.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.FRAGMENT, 0, r, 2);
		}*/
		
		mvp.toVector(cr);
		
		mContext.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, cr, 3);
		mContext.drawTriangles(mIndexBuffer.handle, 0, 2);
		renderer.numCallsToDrawTriangle++;
	}
	
	inline function bindTexture(texture:Texture)
	{
		var o = mRenderer.getTextureObject(texture);
		if (o == null) o = mRenderer.createAndUploadTextureObject(texture);
		mCurrentShader.bindTexture(0, o);
	}
}