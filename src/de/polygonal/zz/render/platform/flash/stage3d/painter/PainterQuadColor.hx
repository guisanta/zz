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
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.data.Color;
import de.polygonal.zz.data.Colori;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalColorShader;
import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.scene.Visual;
import flash.display3D.Context3DProgramType;

@:access(de.polygonal.zz.render.Renderer)
class PainterQuadColor extends PainterQuad
{
	var mColorChannels = new Colori();
	
	public function new(renderer:Stage3dRenderer, featureFlags:Int)
	{
		super(renderer, featureFlags);
		
		mShaderLut.set(PAINTER_FEATURE_COLOR, new AgalColorShader(mContext, featureFlags, 0));	
	}
	
	override public function free() 
	{
		super.free();
		
		mColorChannels = null;
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
	
	override public function draw(renderer:Stage3dRenderer, ?visual:Visual, ?batch:ArrayList<Visual>, min = -1, max = -1)
	{
		assert(visual != null);
		
		renderer.setGlobalState(visual);
		
		var cr = mConstantRegisters;
		
		setShader(PAINTER_FEATURE_COLOR);
		
		var mvp = renderer.setModelViewProjMatrix(visual.world);
		mvp.m13 = 1; //op.zw
		mvp.toVector(cr);
		
		mContext.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, cr, 2);
		
		var a = renderer.currentAlphaMultiplier;
		
		var effect = visual.effect.as(ColorEffect);
		
		//TODO handle color transformation
		//var ct = renderer.currentColorTransform;
		//if (ct != null)
		//{
			//var m = ct.multiplier;
			//var o = ct.offset;
			//cr[0] = (r * m.r + o.r) * (1 / 0xFF);
			//cr[1] = (g * m.g + o.g) * (1 / 0xFF);
			//cr[2] = (b * m.b + o.b) * (1 / 0xFF);
			//cr[3] =  a * m.a + (o.a * (1 / 0xFF));
		//}
		//else
		{
			var rgb = mColorChannels;
			Color.extractR8G8B8(effect.color, rgb); 
			cr[0] = rgb.r;
			cr[1] = rgb.g;
			cr[2] = rgb.b;
			cr[3] = a;
		}
		
		mContext.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, cr, 1);
		mContext.drawTriangles(mIndexBuffer.handle, 0, 2);
		renderer.numCallsToDrawTriangle++;
	}
}