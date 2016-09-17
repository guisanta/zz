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

import de.polygonal.core.math.Vec3;
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.data.Color;
import de.polygonal.zz.data.Colori;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.platform.flash.stage3d.agal.*;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Visual;
import flash.display3D.Context3DProgramType;

@:access(de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer)
class PainterQuadColorBatch extends PainterQuad
{
	//constant batching
	inline static var MAX_SUPPORTED_REGISTERS = 128;
	inline static var NUM_FLOATS_PER_REGISTER = 4;
	
	var mNumSharedRegisters:Int;
	var mNumRegistersPerQuad:Int;
	
	//vertex batching
	var mColorChannels = new Colori();
	var mTmpVertices = [new Vec3(0, 0), new Vec3(1, 0), new Vec3(1, 1), new Vec3(0, 1)]; //TODO needed?
	var mTmpVec3 = new Vec3();
	
	public function new(renderer:Stage3dRenderer, featureFlags:Int, textureFlags:Int)
	{
		super(renderer, featureFlags);
		
		mMaxBatchSize = renderer.maxBatchSize;
		
		switch (renderer.batchStrategy)
		{
			case VertexBufferBatch:
				mCurrentShader = new AgalColorBatchVertex(mContext, featureFlags, 0);
				var numFloatsPerAttribute = [2, 4];
				
				//TODO?
				/*if (mCurrentShader.supportsAlpha()) numFloatsPerAttr.push(1);
				if (mCurrentShader.supportsColorTransform())
				{
					numFloatsPerAttr.push(4);
					numFloatsPerAttr.push(4);
				}*/
				
				mVertexBuffer = new Stage3dVertexBuffer(mContext, numFloatsPerAttribute);
				mVertexBuffer.allocate(mMaxBatchSize * 4);
				
			case ConstantRegisterBatch:
				mCurrentShader = new AgalColorBatchConstant(mContext, featureFlags, 0);
				
				mNumSharedRegisters = 0;
				mNumRegistersPerQuad = 3; //TODO? mCurrentShader.supportsColorTransform() ? 5 : 3;
				
				mConstantRegisters.length = MAX_SUPPORTED_REGISTERS * NUM_FLOATS_PER_REGISTER;
				mConstantRegisters.fixed = true;
				
				var limit = Std.int((MAX_SUPPORTED_REGISTERS - mNumSharedRegisters) / mNumRegistersPerQuad);
				if (mMaxBatchSize > limit) mMaxBatchSize = limit;
				
				mVertexBuffer = new Stage3dVertexBuffer(mContext, [2, 3]);
				mVertexBuffer.allocate(mMaxBatchSize * 4); //uv, index //TODO uv needed?
				
				var address3 = new Vec3();
				for (i in 0...mMaxBatchSize)
				{
					var constRegIndex = mNumSharedRegisters + i * mNumRegistersPerQuad;
					address3.x = constRegIndex + 0;
					address3.y = constRegIndex + 1;
					address3.z = constRegIndex + 2;
					
					for (i in 0...4)
					{
						mVertexBuffer.addFloat2(mTmpVertices[i]);
						mVertexBuffer.addFloat3(address3);
					}
				}
			
			case None: throw "invalid batch strategy";
		}
		
		initIndexBuffer(mMaxBatchSize);
		
		mIndexBuffer.upload();
		mVertexBuffer.upload();
	}
	
	override public function free()
	{
		super.free();
		
		mTmpVertices = null;
	}
	
	override public function bind()
	{
		super.bind();
		
		if (mVertexBuffer == null)
		{
			initVertexBuffer(1, [2]);
			initIndexBuffer(1);
		}
	}
	
	override public function draw(renderer:Stage3dRenderer, ?visual:Visual, ?batch:ArrayList<Visual>, min = -1, max = -1)
	{
		//set program & texture
		mCurrentShader.bindProgram();
		var effect = batch.get(min).effect.as(ColorEffect);
		
		//var hasAlpha = mCurrentShader.supportsAlpha();
		//var hasColorTransform = mCurrentShader.supportsColorTransform();
		//var hasPremultipliedAlpha = mCurrentShader.supportsTexturePremultipliedAlpha();
		
		
		switch (renderer.batchStrategy)
		{
			case VertexBufferBatch:
				{
					//update vertex buffer
					var numTriangles = ((max - min) + 1) * 2;
					
					var stride = mVertexBuffer.numFloatsPerVertex;
					var t = mTmpVec3;
					var tv = mTmpVertices;
					var vb = mVertexBuffer;
					var i = 0;
					var offset, address, size;
					var effect, world;
					
					size = batch.size;
					
					while (min <= max)
					{
						offset = (i << 2) * stride;
						
						var v = batch.get(min++);
						effect = v.effect.as(ColorEffect);
						
						renderer.setGlobalState(v);
						var alpha = renderer.currentAlphaMultiplier;
					
						//update vertices
						world = v.world;
						address = offset;
						
						if (v.type == Quad.TYPE) //[0, 0, 1, 0, 1, 1, 0, 1]
						{
							//[0, 0, 1, 0, 1, 1, 0, 1]
							if (world.isRSMatrix())
							{
								var m = world.getRotate();
								var m11 = m.m11; var m12 = m.m12;
								var m21 = m.m21; var m22 = m.m22;
								world.setRotate(m);
								var t = world.getTranslate();
								var tx = t.x;
								var ty = t.y;
								/*if (world.isUnitScale())
								{
									//Y = R*X + T
									vb.setFloat2f(address,             tx,             ty); address += stride;
									vb.setFloat2f(address, m11       + tx, m21       + ty); address += stride;
									vb.setFloat2f(address, m11 + m12 + tx, m21 + m22 + ty); address += stride;
									vb.setFloat2f(address, m12       + tx, m22       + ty); address += stride;
								}
								else
								{*/
									//Y = R*S*X + T
									var s = world.getScale();
									var sx = s.x;
									var sy = s.y;
									vb.setFloat2f(address,                       tx,                       ty); address += stride;
									vb.setFloat2f(address, m11 * sx            + tx, m21 * sx            + ty); address += stride;
									vb.setFloat2f(address, m11 * sx + m12 * sy + tx, m21 * sx + m22 * sy + ty); address += stride;
									vb.setFloat2f(address, m12 * sy            + tx, m22 * sy            + ty); address += stride;
								//}
							}
							else
							{
								//Y = M*X + T
								var m = world.getMatrix();
								var m11 = m.m11; var m12 = m.m12;
								var m21 = m.m21; var m22 = m.m22;
								var t = world.getTranslate();
								var tx = t.x;
								var ty = t.y;
								
								vb.setFloat2f(address,             tx,             ty); address += stride;
								vb.setFloat2f(address, m11       + tx, m21       + ty); address += stride;
								vb.setFloat2f(address, m11 + m12 + tx, m21 + m22 + ty); address += stride;
								vb.setFloat2f(address, m12       + tx, m22       + ty); address += stride;
							}
						}
						/*else
						{
							world.applyForwardBatch2f(geometry.vertices, tv, 4);
							
							vb.setFloat2(address, tv[0]); address += stride;
							vb.setFloat2(address, tv[1]); address += stride;
							vb.setFloat2(address, tv[2]); address += stride;
							vb.setFloat2(address, tv[3]);
						}*/
						
						offset += 2;
						
						var c = effect.color;
						
						var rgb = mColorChannels;
						Color.extractR8G8B8(effect.color, rgb); 
						var r = rgb.r;
						var g = rgb.g;
						var b = rgb.b;
						var a = alpha;
						
						//if (effect.colorTransform != null)
						//{
							//var m = effect.colorTransform.multiplier;
							//var o = effect.colorTransform.offset;
							//t.x = (r * m.r + o.r) * (1 / 0xFF);
							//t.y = (g * m.g + o.g) * (1 / 0xFF);
							//t.z = (b * m.b + o.b) * (1 / 0xFF);
							//t.w =  a * m.a + (o.a * (1 / 0xFF));
						//}
						//else
						//{
							t.x = r * (1 / 0xFF);
							t.y = g * (1 / 0xFF);
							t.z = b * (1 / 0xFF);
							t.w = a;
						//}
						
						address = offset;
						vb.setFloat4(address, t); address += stride;
						vb.setFloat4(address, t); address += stride;
						vb.setFloat4(address, t); address += stride;
						vb.setFloat4(address, t);
						
						i++;
					}

					vb.upload();

					var cr = mConstantRegisters;

					//setShader

					var vp = renderer.currentViewProjMat;
					vp.m13 = 1; //op.zw
					vp.toVector(cr);

					mContext.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.VERTEX, 0, cr, 2);
					mContext.drawTriangles(mIndexBuffer.handle, 0, numTriangles);
					renderer.numCallsToDrawTriangle++;
				}
			
			case ConstantRegisterBatch:
				{
					var cr = mConstantRegisters;
					
					var v;
					var changed = false;
					/*var stride = mVertexBuffer.numFloatsPerVertex;
					for (i in 0...batch.size())
					{
						var g = batch.get(i);
						throw 'TODO';
						//if (g.hasModelChanged())
						//{
							//changed = true;
							//var address = (i << 2) * stride;
							//mVertexBuffer.setFloat2(address, g.vertices[0]); address += stride;
							//mVertexBuffer.setFloat2(address, g.vertices[1]); address += stride;
							//mVertexBuffer.setFloat2(address, g.vertices[2]); address += stride;
							//mVertexBuffer.setFloat2(address, g.vertices[3]);
						//}
					}*/

					if (changed) mVertexBuffer.upload();
					
					var size = (max - min) + 1;
					
					var effect:ColorEffect, mvp, alpha;
					var offset;
					var capacity = mMaxBatchSize;
					var fullPasses:Int = cast size / capacity;
					var remainder = size % capacity;
					
					for (pass in 0...fullPasses)
					{
						for (i in 0...capacity)
						{
							v = batch.get(min++);
							
							renderer.setGlobalState(v);
							alpha = renderer.currentAlphaMultiplier;
							
							effect = v.effect.as(ColorEffect);
							
							mvp = renderer.setModelViewProjMatrix(v.world);
							//crop = effect.cropRectUv;
							
							//use 2 constant registers (each 4 floats) for mvp matrix and alpha (+2 constant registers for color transform)
							offset = (mNumSharedRegisters * NUM_FLOATS_PER_REGISTER) + i * (mNumRegistersPerQuad * NUM_FLOATS_PER_REGISTER);
							
							cr[offset +  0] = mvp.m11;
							cr[offset +  1] = mvp.m12;
							cr[offset +  2] = 1; //op.zw = 1
							cr[offset +  3] = mvp.m14;
							
							cr[offset +  4] = mvp.m21;
							cr[offset +  5] = mvp.m22;
							cr[offset +  6] = 1; //unused
							cr[offset +  7] = mvp.m24;
							
							//throw 'TODO';
							var c = effect.color;
							
							var rgb = mColorChannels;
							Color.extractR8G8B8(effect.color, rgb); 
							var r = rgb.r;
							var g = rgb.g;
							var b = rgb.b;
							var a = alpha;
							
							//var c = 0;
							//var r = c.getR();
							//var g = c.getG();
							//var b = c.getB();
							//var a = effect.alpha;
							//if (effect.colorTransform != null)
							//{
								//var m = effect.colorTransform.multiplier;
								//var o = effect.colorTransform.offset;
								//cr[offset +  8] = (r * m.r + o.r) * (1 / 0xFF);
								//cr[offset +  9] = (g * m.g + o.g) * (1 / 0xFF);
								//cr[offset + 10] = (b * m.b + o.b) * (1 / 0xFF);
								//cr[offset + 11] =  a * m.a + (o.a * (1 / 0xFF));
							//}
							//else
							//{
								cr[offset +  8] = r * (1 / 0xFF);
								cr[offset +  9] = g * (1 / 0xFF);
								cr[offset + 10] = b * (1 / 0xFF);
								cr[offset + 11] = a;
							//}
						}
						
						mContext.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, cr,
						mNumSharedRegisters + capacity * mNumRegistersPerQuad);
						mContext.drawTriangles(mIndexBuffer.handle, 0, capacity * 2);
						renderer.numCallsToDrawTriangle++;
					}
					
					if (remainder > 0)
					{
						for (i in 0...remainder)
						{
							v = batch.get(min++);
							effect = v.effect.as(ColorEffect);
							
							renderer.setGlobalState(v);
							alpha = renderer.currentAlphaMultiplier;
							
							mvp = renderer.setModelViewProjMatrix(v.world);
							offset = (mNumSharedRegisters * NUM_FLOATS_PER_REGISTER) + i * (mNumRegistersPerQuad * NUM_FLOATS_PER_REGISTER);
							cr[offset +  0] = mvp.m11;
							cr[offset +  1] = mvp.m12;
							cr[offset +  2] = 1;
							cr[offset +  3] = mvp.m14;
							
							cr[offset +  4] = mvp.m21;
							cr[offset +  5] = mvp.m22;
							cr[offset +  6] = 1;
							cr[offset +  7] = mvp.m24;
							
							var rgb = mColorChannels;
							Color.extractR8G8B8(effect.color, rgb); 
							var r = rgb.r;
							var g = rgb.g;
							var b = rgb.b;
							var a = alpha;
							
							//if (effect.colorTransform != null)
							//{
								//var m = effect.colorTransform.multiplier;
								//var o = effect.colorTransform.offset;
								//cr[offset +  8] = (r * m.r + o.r) * (1 / 0xFF);
								//cr[offset +  9] = (g * m.g + o.g) * (1 / 0xFF);
								//cr[offset + 10] = (b * m.b + o.b) * (1 / 0xFF);
								//cr[offset + 11] =  a * m.a + (o.a * (1 / 0xFF));
							//}
							//else
							//{
								cr[offset +  8] = r * (1 / 0xFF);
								cr[offset +  9] = g * (1 / 0xFF);
								cr[offset + 10] = b * (1 / 0xFF);
								cr[offset + 11] = a;
							//}
						}
						
						mContext.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, cr,
							mNumSharedRegisters + remainder * mNumRegistersPerQuad);
						mContext.drawTriangles(mIndexBuffer.handle, 0, remainder * 2);
						renderer.numCallsToDrawTriangle++;
					}
				}
			
			case None: throw "invalid batch strategy";
		}
	}
}