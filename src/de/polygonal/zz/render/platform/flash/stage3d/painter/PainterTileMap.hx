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

import de.polygonal.core.math.Mat44;
import de.polygonal.ds.ArrayList;
import de.polygonal.zz.render.effect.TileMapEffect;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalTextureBatchVertex;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dIndexBuffer;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dVertexBuffer;
import de.polygonal.zz.scene.Visual;
import flash.Lib;
import flash.Vector;

//TODO integreate into global batch rendering
@:access(de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer)
class PainterTileMap extends Painter
{
	inline public static var NUM_PREALLOCATED_TILES = 50 * 50;
	
	var mVertexData:Vector<Float>;
	var mIndexData:Vector<Int>;
	var mTmpMat = new Mat44();
	
	public function new(renderer:Stage3dRenderer, featureFlags:Int, textureFlags:Int) 
	{
		var effectFlags = 0; //TODO flags
		
		super(renderer, effectFlags);
		
		mCurrentShader = new AgalTextureBatchVertex(mContext, featureFlags, textureFlags);
		mIndexBuffer = new Stage3dIndexBuffer(mContext);
		mVertexBuffer = new Stage3dVertexBuffer(mContext, [2, 2]);
	}
	
	override public function draw(renderer:Stage3dRenderer, ?visual:Visual, ?batch:ArrayList<Visual>, min = -1, max = -1)
	{
		var effect = Lib.as(renderer.currentEffect, TileMapEffect);
		var numTiles = effect.numVisTilesX * effect.numVisTilesY;
		
		//number of tiles changed?
		if (effect.sizeChanged)
		{
			//update vertex/index buffers
			makeGrid(effect.numVisTilesX, effect.numVisTilesY, effect.tileSize);
			
			var numIndices = numTiles * 6; //two triangles per tile (=6 indices)
			mIndexBuffer.clear();
			for (i in 0...numIndices) mIndexBuffer.add(mIndexData[i]);
			mIndexBuffer.upload();
			
			mVertexBuffer.allocate(numTiles * 4);
		}
		
		//tile content changed?
		if (effect.redraw)
		{
			var vb = mVertexBuffer;
			var stride = vb.numFloatsPerVertex;
			
			var tiles = effect.screenTiles;
			var atlas = effect.atlas;
			var ax, ay, bx, by, cx, cy, dx, dy, uv;
			var offset, addr, gid;
			var vd = mVertexData;
			
			var j = 0;
			for (i in 0...numTiles)
			{
				gid = tiles.getAtIndex(i);
				
				offset = (i << 2) * stride;
				addr = offset;
				
				ax = vd[j + 0];
				ay = vd[j + 1];
				bx = vd[j + 2];
				by = vd[j + 3];
				cx = vd[j + 4];
				cy = vd[j + 5];
				dx = vd[j + 6];
				dy = vd[j + 7];
				
				j += 8;
				
				//TODO use add method?
				
				//position
				if (gid != -1) //drawable tile?
				{
					vb.setFloat2f(addr, ax, ay); addr += stride;
					vb.setFloat2f(addr, bx, by); addr += stride;
					vb.setFloat2f(addr, cx, cy); addr += stride;
					vb.setFloat2f(addr, dx, dy);
				}
				else
				{
					//skip drawing (make degenerate)
					vb.setFloat2f(addr, ax, ay); addr += stride;
					vb.setFloat2f(addr, bx, by); addr += stride;
					vb.setFloat2f(addr, bx, by); addr += stride;
					vb.setFloat2f(addr, ax, ay);
				}
				
				offset += 2;
				addr = offset;
				
				//uv
				if (gid != -1)
				{
					uv = atlas.getFrameById(gid).texCoordUv;
					vb.setFloat2f(addr, uv.x       , uv.y       ); addr += stride;
					vb.setFloat2f(addr, uv.x + uv.w, uv.y       ); addr += stride;
					vb.setFloat2f(addr, uv.x + uv.w, uv.y + uv.h); addr += stride;
					vb.setFloat2f(addr, uv.x       , uv.y + uv.h);
				}
				else
				{
					//skip drawing (degenerate)
					vb.setFloat2f(addr, 0, 0); addr += stride;
					vb.setFloat2f(addr, 0, 0); addr += stride;
					vb.setFloat2f(addr, 0, 0); addr += stride;
					vb.setFloat2f(addr, 0, 0);
				}
			}
			
			vb.upload();
		}
		
		var world = renderer.currentVisual.world;
		
		var vp = mTmpMat;
		vp.setAsIdentity();
		vp.tx = world.getTranslate().x;
		vp.ty = world.getTranslate().y;
		vp.cat(renderer.currentViewProjMat);
		vp.m13 = 1; //op.zw
		
		var cr = mConstantRegisters;
		vp.toVector(cr);
		
		mContext.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.VERTEX, 0, cr, 2);
		
		mCurrentShader.bindProgram(); //TODO only if changed
		
		throw 'TODO';
		//mCurrentShader.bindTexture(0, renderer.mNewStage3dTexture.handle); //TODO only if changed
		mVertexBuffer.bind();
		
		mContext.drawTriangles(mIndexBuffer.handle, 0, numTiles * 2); //every quad has two triangles
		renderer.numCallsToDrawTriangle++;
		
		mVertexBuffer.unbind(); //TODO only if changed
	}
	
	function makeGrid(numTilesX:Int, numTilesY:Int, tileSize:Int)
	{
		var numTiles = numTilesX * numTilesY;
		
		L.e('makeGrid $numTiles');
		
		var vd = mVertexData;
		var id = mIndexData;
		
		if (vd == null || vd.length < numTiles * 8)
		{
			vd = new Vector<Float>(numTiles * 8, true);
			id = new Vector<Int>(numTiles * 6, true);
			
			mVertexData = vd;
			mIndexData = id;
			
			L.e('resize vertex buffer $numTiles');
		}
		
		var inflate = tileSize * .01; //inflate by one percent to prevent flickering when zooming/rotating
		var s = tileSize;
		var i = 0, j = 0, k = 0;
		var a, b;
		for (y in 0...numTilesY)
		{
			for (x in 0...numTilesX)
			{
				a = x + 1;
				b = y + 1;
				
				vd[i + 0] = (x * s) - inflate;
				vd[i + 1] = (y * s) - inflate;
				vd[i + 2] = (a * s) + inflate;
				vd[i + 3] = (y * s) - inflate;
				vd[i + 4] = (a * s) + inflate;
				vd[i + 5] = (b * s) + inflate;
				vd[i + 6] = (x * s) - inflate;
				vd[i + 7] = (b * s) + inflate;
				
				id[j + 0] = k;
				id[j + 1] = k + 1;
				id[j + 2] = k + 2;
				id[j + 3] = k;
				id[j + 4] = k + 2;
				id[j + 5] = k + 3;
				
				i += 8;
				j += 6;
				k += 4;
			}
		}
	}
}