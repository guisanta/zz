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

import de.polygonal.core.math.Rectf;
import de.polygonal.core.math.Vec3;
import de.polygonal.ds.Da;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalTextureBatchConstant;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalTextureBatchVertex;
import de.polygonal.zz.render.platform.flash.stage3d.painter.PainterFeature.*;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.scene.Quad;
import de.polygonal.zz.scene.Visual;
import de.polygonal.zz.texture.Texture;
import flash.display3D.Context3DProgramType;

//TODO use init() method for allocating buffer

@:access(de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer)
class PainterQuadTextureBatch extends PainterQuad
{
	//constant batching
	inline static var MAX_SUPPORTED_REGISTERS = 128;
	inline static var NUM_FLOATS_PER_REGISTER = 4;
	
	var mNumSharedRegisters:Int;
	var mNumRegistersPerQuad:Int;
	
	//vertex batching
	var mTmpVertices =  [new Vec3(0, 0), new Vec3(1, 0), new Vec3(1, 1), new Vec3(0, 1)];
	var mUv0 = new Vec3();
	var mUv1 = new Vec3();
	var mUv2 = new Vec3();
	var mUv3 = new Vec3();
	
	var mTmpVec3 = new Vec3();
	
	public function new(renderer:Stage3dRenderer, featureFlags:Int, textureFlags:Int)
	{
		super(renderer, featureFlags);
		
		mMaxBatchSize = renderer.maxBatchSize;
		
		switch (renderer.batchStrategy)
		{
			case VertexBufferBatch:
				mCurrentShader = new AgalTextureBatchVertex(mContext, featureFlags, textureFlags);
				
				var numFloatsPerAttr = [2, 2];
				if (mCurrentShader.supportsAlpha()) numFloatsPerAttr.push(1);
				if (mCurrentShader.supportsColorTransform())
				{
					numFloatsPerAttr.push(4);
					numFloatsPerAttr.push(4);
				}
				mVertexBuffer = new Stage3dVertexBuffer(mContext, numFloatsPerAttr);
				mVertexBuffer.allocate(mMaxBatchSize * 4);
			
			case ConstantRegisterBatch:
				mCurrentShader = new AgalTextureBatchConstant(mContext, featureFlags, textureFlags);
				
				mNumSharedRegisters = 0;
				mNumRegistersPerQuad = mCurrentShader.supportsColorTransform() ? 5 : 3;
				
				mConstantRegisters.length = MAX_SUPPORTED_REGISTERS * NUM_FLOATS_PER_REGISTER;
				mConstantRegisters.fixed = true;
				
				var limit = Std.int((MAX_SUPPORTED_REGISTERS - mNumSharedRegisters) / mNumRegistersPerQuad);
				if (mMaxBatchSize > limit) mMaxBatchSize = limit;
				
				mVertexBuffer = new Stage3dVertexBuffer(mContext, mCurrentShader.supportsColorTransform() ? [2, 3, 2] : [2, 3]);
				mVertexBuffer.allocate(mMaxBatchSize * 4);
				
				var address3 = new Vec3();
				var address2 = new Vec3();
				for (i in 0...mMaxBatchSize)
				{
					var constRegIndex = mNumSharedRegisters + i * mNumRegistersPerQuad;
					address3.x = constRegIndex + 0;
					address3.y = constRegIndex + 1;
					address3.z = constRegIndex + 2;
					
					if (mCurrentShader.supportsColorTransform())
					{
						address2.x = constRegIndex + 3;
						address2.y = constRegIndex + 4;
						
						for (i in 0...4)
						{
							mVertexBuffer.addFloat2(mTmpVertices[i]);
							mVertexBuffer.addFloat3(address3);
							mVertexBuffer.addFloat2(address2);
						}
					}
					else
					{
						for (i in 0...4)
						{
							mVertexBuffer.addFloat2(mTmpVertices[i]);
							mVertexBuffer.addFloat3(address3);
						}
					}
				}
			
			case None: throw "invalid batch strategy";
		}
		
		mVertexBuffer.upload();
		
		initIndexBuffer(mMaxBatchSize);
		mIndexBuffer.upload();
	}
	
	override public function free()
	{
		super.free();
		
		mTmpVertices = null;
		mUv0 = null;
		mUv1 = null;
		mUv2 = null;
		mUv3 = null;
	}
	
	override public function unbind() 
	{
		super.unbind();
		
		mCurrentShader.unbindTexture(0);
	}
	
	override public function draw(renderer:Stage3dRenderer, ?visual:Visual, ?batch:Da<Visual>, min = -1, max = -1)
	{
		//set program & texture
		mCurrentShader.bindProgram();
		var effect = batch.get(min).effect.as(TextureEffect);
		bindTexture(effect.texture);
		
		var hasAlpha = mCurrentShader.supportsAlpha();
		var hasColorTransform = mCurrentShader.supportsColorTransform();
		var hasPremultipliedAlpha = mCurrentShader.supportsTexturePremultipliedAlpha();
		
		switch (renderer.batchStrategy)
		{
			case VertexBufferBatch:
				{
					//update vertex buffer
					var numTriangles = ((max - min) + 1) * 2;
					
					var vb = mVertexBuffer;
					var uv0 = mUv0;
					var uv1 = mUv1;
					var uv2 = mUv2;
					var uv3 = mUv3;
					var t = mTmpVec3;
					var i = 0;
					var stride = mVertexBuffer.numFloatsPerVertex;
					var offset, address;
					var v, effect, world, crop, x, y, w, h, alpha;
					while (min <= max)
					{
						offset = (i << 2) * stride;
						
						v = batch.get(min++);
						effect = v.effect.as(TextureEffect);
						
						renderer.setGlobalState(v);
						alpha = renderer.currentAlphaMultiplier;
						
						//update vertex positions
						world = v.world;
						address = offset;
						
						//TODO optimize
						if (v.type == Quad.TYPE) //[0, 0, 1, 0, 1, 1, 0, 1]
						{
							if (world.isRSMatrix())
							{
								var m = world.getRotate();
								var m11 = m.m11; var m12 = m.m12;
								var m21 = m.m21; var m22 = m.m22;
								world.setRotate(m); //TODO required?
								var t = world.getTranslate();
								var tx = t.x;
								var ty = t.y;
								
								//if (world.isUnitScale())
								//{
									//Y = R*X + T
									//vb.setFloat2f(address,             tx,             ty); address += stride;
									//vb.setFloat2f(address, m11       + tx, m21       + ty); address += stride;
									//vb.setFloat2f(address, m11 + m12 + tx, m21 + m22 + ty); address += stride;
									//vb.setFloat2f(address, m12       + tx, m22       + ty); address += stride;
								//}
								//else
								//{
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
						else
						{
							throw 1; //TODO optimize
							//var tv = mTmpVertices;
							//var out = new haxe.ds.Vector<Vec3> = new haxe.ds.Vector<Vec3>();
							//world.applyForwardBatchf(v.vertices, 
							
							//world.applyForwardArr2(v.vertices, tv, 4);
							
							//vb.setFloat2(address, tv[0]); address += stride;
							//vb.setFloat2(address, tv[1]); address += stride;
							//vb.setFloat2(address, tv[2]); address += stride;
							//vb.setFloat2(address, tv[3]);
						}
						offset += 2;
						
						
						
						
						
						
						
						
						//update uv coordinates
						crop = effect.cropRectUv;
						x = crop.x + effect.uvOffsetX;
						y = crop.y + effect.uvOffsetY;
						w = crop.w * effect.uvScaleX;
						h = crop.h * effect.uvScaleY;
						
						uv0.x = x;		//0 * w + x
						uv0.y = y;		//0 * h + y
						uv1.x = w + x;	//1 * w + x
						uv1.y = y;		//0 * h + y
						uv2.x = w + x;	//1 * w + x
						uv2.y = h + y;	//1 * h + y
						uv3.x = x;		//0 * w + x
						uv3.y = h + y;	//1 * h + y
						
						address = offset;
						vb.setFloat2(address, uv0); address += stride;
						vb.setFloat2(address, uv1); address += stride;
						vb.setFloat2(address, uv2); address += stride;
						vb.setFloat2(address, uv3);
						offset += 2;
						
						//update alpha multiplier
						if (hasAlpha)
						{
							address = offset;
							vb.setFloat1f(address, alpha); address += stride;
							vb.setFloat1f(address, alpha); address += stride;
							vb.setFloat1f(address, alpha); address += stride;
							vb.setFloat1f(address, alpha);
							offset++;
						}
						
						//TODO support color transformation
						/*if (hasColorTransform)
						{
							//update color transformation
							var mult = effect.colorTransform.multiplier;
							//t.set(effect.colorTransform.multiplier);
							t.x = mult.r;
							t.y = mult.g;
							t.z = mult.b;
							
							if (hasPremultipliedAlpha)
							{
								var am = t.w;
								t.x *= am * alpha;
								t.y *= am * alpha;
								t.z *= am * alpha;
								t.w *= alpha;
							}
							else
								t.w *= alpha;
							
							var address = offset;
							vb.setFloat4(address, t); address += stride;
							vb.setFloat4(address, t); address += stride;
							vb.setFloat4(address, t); address += stride;
							vb.setFloat4(address, t);
							
							offset += 4;
							
							var off = effect.colorTransform.offset;
							t.x = off.r;
							t.y = off.g;
							t.z = off.b;
							//t.set(effect.colorTransform.offset);
							
							t.x *= INV_FF;
							t.y *= INV_FF;
							t.z *= INV_FF;
							t.w *= INV_FF;
							address = offset;
							vb.setFloat4(address, t); address += stride;
							vb.setFloat4(address, t); address += stride;
							vb.setFloat4(address, t); address += stride;
							vb.setFloat4(address, t);
							
							offset += 4;
						}*/
						
						i++;
					}
					
					vb.upload();
					
					//draw triangles
					var cr = mConstantRegisters;
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
					var stride = mVertexBuffer.numFloatsPerVertex;
					
					if (changed) mVertexBuffer.upload(); //TODO?
					
					var size = (max - min) + 1;
					
					var effect:TextureEffect, mvp, crop:Rectf, alpha;
					var offset;
					var capacity = mMaxBatchSize;
					var fullPasses:Int = cast size / capacity;
					var remainder = size % capacity;
					
					inline function write()
					{
						cr[offset +  0] = mvp.m11;
						cr[offset +  1] = mvp.m12;
						cr[offset +  2] = 1; //op.zw = 1
						cr[offset +  3] = mvp.m14;
						
						cr[offset +  4] = mvp.m21;
						cr[offset +  5] = mvp.m22;
						cr[offset +  6] = alpha;
						cr[offset +  7] = mvp.m24;
					
						cr[offset +  8] = crop.w * effect.uvScaleX;
						cr[offset +  9] = crop.h * effect.uvScaleY;
						cr[offset + 10] = crop.x + effect.uvOffsetX;
						cr[offset + 11] = crop.y + effect.uvOffsetY;
					}
					
					for (pass in 0...fullPasses)
					{
						for (i in 0...capacity)
						{
							v = batch.get(min++);
							
							renderer.setGlobalState(v);
							alpha = renderer.currentAlphaMultiplier; //TODO set once?
							
							effect = v.effect.as(TextureEffect);
							
							mvp = renderer.setModelViewProjMatrix(v.world);
							crop = effect.cropRectUv;
							
							//use 3 constant registers (each 4 floats) for mvp matrix, alpha and uv crop (+2 constant registers for color transform)
							offset = (mNumSharedRegisters * NUM_FLOATS_PER_REGISTER) + i * (mNumRegistersPerQuad * NUM_FLOATS_PER_REGISTER);
							
							write();
							
							//TODO support color transformation
							/*if (hasColorTransform)
							{
								var t = effect.colorTransform.multiplier;
								if (hasPremultipliedAlpha)
								{
									var am = t.a;
									cr[offset + 12] = t.r * am * alpha;
									cr[offset + 13] = t.g * am * alpha;
									cr[offset + 14] = t.b * am * alpha;
									cr[offset + 15] = t.a * alpha;
								}
								else
								{
									cr[offset + 12] = t.r;
									cr[offset + 13] = t.g;
									cr[offset + 14] = t.b;
									cr[offset + 15] = t.a * alpha;
								}
								
								t = effect.colorTransform.offset;
								cr[offset + 16] = t.r * INV_FF;
								cr[offset + 17] = t.g * INV_FF;
								cr[offset + 18] = t.b * INV_FF;
								cr[offset + 19] = t.a * INV_FF;
							}*/
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
							effect = cast(v.effect, TextureEffect); //TODO cast
							
							mvp = renderer.setModelViewProjMatrix(v.world);
							crop = effect.cropRectUv;
							offset = (mNumSharedRegisters * NUM_FLOATS_PER_REGISTER) + i * (mNumRegistersPerQuad * NUM_FLOATS_PER_REGISTER);
							
							//TODO needed?
							renderer.setGlobalState(v);
							alpha = renderer.currentAlphaMultiplier;
							
							write();
							
							//TODO support color transformation
							/*if (hasColorTransform)
							{
								var t = effect.colorTransform.multiplier;
								cr[offset + 12] = t.r;
								cr[offset + 13] = t.g;
								cr[offset + 14] = t.b;
								cr[offset + 15] = t.a;
								
								t = effect.colorTransform.offset;
								cr[offset + 16] = t.r * INV_FF;
								cr[offset + 17] = t.g * INV_FF;
								cr[offset + 18] = t.b * INV_FF;
								cr[offset + 19] = t.a * INV_FF;
							}*/
						}
						
						mContext.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, cr, mNumSharedRegisters + remainder * mNumRegistersPerQuad);
						mContext.drawTriangles(mIndexBuffer.handle, 0, remainder * 2);
						renderer.numCallsToDrawTriangle++;
					}
				}
			
			case None: throw "invalid batch strategy";
		}
	}
	
	inline function bindTexture(texture:Texture)
	{
		var o = mRenderer.getTextureObject(texture);
		if (o == null) o = mRenderer.createAndUploadTextureObject(texture);
		mCurrentShader.bindTexture(0, o);
	}
}

/*for (i in 0...count)
	{
		visual = batch[i];
		
		if (Std.is(visual, Quad)) continue;
		//if (visual.type == GeometryType.UNIT_QUAD) continue;
		
		//if (visual.hasModelChanged())
		//{
			//changed = true;
			//var address = (i << 2) * stride;
			
			_vb.setFloat2(address, visual.vertices[0]); address += stride;
			mVertexBuffer.setFloat2(address, visual.vertices[1]); address += stride;
			mVertexBuffer.setFloat2(address, visual.vertices[2]); address += stride;
			mVertexBuffer.setFloat2(address, visual.vertices[3]);
		//}
	}*/