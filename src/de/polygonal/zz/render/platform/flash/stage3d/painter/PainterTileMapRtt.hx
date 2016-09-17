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
import de.polygonal.core.math.Mathematics;
import de.polygonal.core.math.Rectf;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.data.Size.Sizei;
import de.polygonal.zz.render.effect.TileMapEffect;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalShader;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalTextureShader;
import de.polygonal.zz.render.platform.flash.stage3d.agal.AgalTextureVertexBatch;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dIndexBuffer;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer;
import de.polygonal.zz.render.platform.flash.stage3d.Stage3dVertexBuffer;
import de.polygonal.zz.scene.Xform;
import flash.display.BitmapData;
import flash.display3D.Context3D;
import flash.display3D.Context3DTextureFormat;
import flash.display3D.textures.Texture;
import flash.Vector;

//2. render to texture http://jacksondunstan.com/articles/1998
//3. vbo, ido - allocate more upfront for scaling/rotation? 
//do not inflate when using render to texture
//4. batch rendering

@:access(de.polygonal.zz.render.platform.flash.stage3d.Stage3dRenderer)
class PainterTileMapRtt extends Painter
{
	public static var RTT:Bool = false;
	
	var mShader:AgalShader;
	
	
	var mIndexData:Vector<Int>;
	var mVertexData:Vector<Float>;
	
	var mTexture:Texture;
	
	
	var mShader2:AgalShader;
	var mVertexBuffer2:Stage3dVertexBuffer; //RTT
	var mIndexBuffer2:Stage3dIndexBuffer; //RTT
	
	public static var last:Int;
		
	public function new(context:Context3D) 
	{
		var effectFlags = 0;
		var textureFlags = Stage3dTextureFlag.PRESET_QUALITY_LOW;
		
		super(context, effectFlags, textureFlags);
		
		mShader = new AgalTextureVertexBatch(mContext, effectFlags, textureFlags);
		
		mShader2 = new AgalTextureShader(mContext, effectFlags, textureFlags);
		mVertexBuffer2 = new Stage3dVertexBuffer(ctx);
		mVertexBuffer2.allocate([2], 4);
		mVertexBuffer2.addFloat2f(0, 0);
		mVertexBuffer2.addFloat2f(1, 0);
		mVertexBuffer2.addFloat2f(1, 1);
		mVertexBuffer2.addFloat2f(0, 1);
		mVertexBuffer2.upload();
		
		mIndexBuffer2 = new Stage3dIndexBuffer(ctx);
		mIndexBuffer2.add(0);
		mIndexBuffer2.add(1);
		mIndexBuffer2.add(2);
		mIndexBuffer2.add(0);
		mIndexBuffer2.add(2);
		mIndexBuffer2.add(3);
		mIndexBuffer2.upload();
	}
	
	function makeGrid(numTilesX:Int, numTilesY:Int, tileSize:Int)
	{
		var numTiles = numTilesX * numTilesY;
		
		var vb = new Vector<Float>(numTiles * 8);
		var ib = new Vector<Int>(numTiles * 6);
		
		var inflate = tileSize * .01; //inflate by 1% to prevent flickering when zooming/rotating
		var s = tileSize;
		var i = 0, j = 0, k = 0;
		var a, b;
		for (y in 0...numTilesY)
		{
			for (x in 0...numTilesX)
			{
				a = x + 1;
				b = y + 1;
				
				vb[i    ] = (x * s) - inflate;
				vb[i + 1] = (y * s) - inflate;
				vb[i + 2] = (a * s) + inflate;
				vb[i + 3] = (y * s) - inflate;
				vb[i + 4] = (a * s) + inflate;
				vb[i + 5] = (b * s) + inflate;
				vb[i + 6] = (x * s) - inflate;
				vb[i + 7] = (b * s) + inflate;
				
				ib[j    ] = k;
				ib[j + 1] = k + 1;
				ib[j + 2] = k + 2;
				ib[j + 3] = k;
				ib[j + 4] = k + 2;
				ib[j + 5] = k + 3;
				
				i += 8;
				j += 6;
				k += 4;
			}
		}
		
		this.mVertexData = vb;
		this.mIndexData = ib;
	}
	
	public function draw(renderer:Stage3dRenderer, effect:TileMapEffect)
	{
		var mvp = renderer.setModelViewProjMatrix(renderer.currentVisual);
		
		var numTiles = effect.numVisTilesX * effect.numVisTilesY;
		
		if (effect.sizeChanged)
		{
			//rebuild vertex and index buffers
			
			trace('size chnage');
			
			makeGrid(effect.numVisTilesX, effect.numVisTilesY, effect.tileSize);
			
			//TODO don't recreate it
			//create, fill, upload index buffer - can allocate more upfront for rotation/scaling
			if (mIndexBuffer != null)
				mIndexBuffer.free();
			mIndexBuffer = new Stage3dIndexBuffer(mContext);
			for (i in 0...mIndexData.length)
				mIndexBuffer.add(mIndexData[i]);
			mIndexBuffer.upload();
			
			//unload, unbind?
			//create, fill, upload vertex buffer - can allocate more upfront for rotation/scaling
			mVertexBuffer = new Stage3dVertexBuffer(mContext);
			mVertexBuffer.allocate([2, 2], numTiles * 4); //num tiles / every tile has 4 vertices
			
			if (RTT)
			{
				var w = Mathematics.nextPow2(effect.screenTiles.getW() * effect.tileSize);
				trace( "w : " + w );
				var h = Mathematics.nextPow2(effect.screenTiles.getH() * effect.tileSize);
				trace( "h : " + h );
				
				//var w = M.nextPow2(effect.numVisTilesX * effect.tileSize);
				//var h = M.nextPow2(effect.numVisTilesY * effect.tileSize);
				
				//TODO multiple layers
				mTexture = mContext.createTexture(w, h,
					Context3DTextureFormat.BGRA, true, 0);
				mTexture.uploadFromBitmapData(new BitmapData(w, h, true, 0xFFFF8000)); //TODO determine best size
			}
		}
		
		if (effect.redraw)
		{
			var stride = mVertexBuffer.numFloatsPerVertex;
			var vb = mVertexBuffer;
			
			var tiles = effect.screenTiles;
			var atlas = effect.atlas;
			var ax, ay, bx, by, cx, cy, dx, dy;
			var offset, addr, gid;
			var uv;
			
			var j = 0;
			for (i in 0...numTiles)
			{
				gid = tiles.getAtIndex(i);
				
				offset = (i << 2) * stride;
				addr = offset;
				
				ax = mVertexData[j    ];
				ay = mVertexData[j + 1];
				bx = mVertexData[j + 2];
				by = mVertexData[j + 3];
				cx = mVertexData[j + 4];
				cy = mVertexData[j + 5];
				dx = mVertexData[j + 6];
				dy = mVertexData[j + 7];
				
				j += 8;
				
				if (gid != -1)
				{
					vb.setFloat2f(addr, ax, ay); addr += stride;
					vb.setFloat2f(addr, bx, by); addr += stride;
					vb.setFloat2f(addr, cx, cy); addr += stride;
					vb.setFloat2f(addr, dx, dy);
				}
				else
				{
					//skip drawing (degenerate)
					vb.setFloat2f(addr, ax, ay); addr += stride;
					vb.setFloat2f(addr, bx, by); addr += stride;
					vb.setFloat2f(addr, bx, by); addr += stride;
					vb.setFloat2f(addr, ax, ay);
				}
				
				offset += 2;
				
				addr = offset;
				
				if (gid > 0)
				{
					uv = atlas.getFrameAtIndex(gid).texCoordUv;
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
			
			vb.upload(numTiles * 4);
			
			//vb.bind(); //TODO unbind prev if changed
			
			if (RTT)
			{
				assert(mTexture != null);
				
				//mContext.present();
				
				mContext.setRenderToTexture(mTexture, true, 0); //TODO no depth + stencil
				mContext.clear();
				
					//TODO adjust projection matrix!
					var m = new Mat44();
					//default projection space is from [-1,1]
					m.tx = -1;
					m.ty = 1;
					//projection components
					var s = new Sizei(1024, 512);
					m.m11 = 2 / s.x;
					m.m22 = 2 / s.y;
					//flip y-axis
					m.m22 *= -1; 
				
					//var vp = renderer.currentViewProjMat;
					var vp = m;
					vp.m13 = 1; //op.zw
					var constantRegisters = new Vector<Float>();
					vp.toVector(constantRegisters);
					mContext.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.VERTEX, 0, constantRegisters, 2);
					mShader.bindProgram();
					mShader.bindTexture(0, renderer.mNewStage3dTexture.handle);
					mContext.drawTriangles(mIndexBuffer.handle, 0, numTiles * 2);
				
				mContext.present();
				
				mContext.setRenderToBackBuffer();
				mContext.clear();
			}
		}
		
		mVertexBuffer.bind();
		
		if (RTT)
		{
			mVertexBuffer.unbind();
			mVertexBuffer2.bind();
			
			mShader.unbindTexture(0);
			
			mShader2.bindProgram();
			mShader2.bindTexture(0, mTexture);
			
			//var tw = effect.numVisTilesX * effect.tileSize;
			//var th = effect.numVisTilesY * effect.tileSize;
			
			var tw = effect.screenTiles.getW() * effect.tileSize;
			var th = effect.screenTiles.getH() * effect.tileSize;
			
			var world = renderer.currentVisual.world;
			var t = new Xform();
			t.setScale2(tw, th);
			t.setTranslate2(world.getTranslate().x, world.getTranslate().y);
			
			var mvp = renderer.currentMvp;
			t.getHMatrix(mvp);
			mvp.cat(renderer.currentViewProjMat);
			
			var twp2 = M.nextPow2(effect.screenTiles.getW() * effect.tileSize);
			var thp2 = M.nextPow2(effect.screenTiles.getH() * effect.tileSize);
			var uvw = tw / twp2;
			var uvh = th / thp2;
			var crop = new Rectf(0, 0, uvw, uvh);
			
			var alpha = 1;
			mvp.m13 = alpha;
			mvp.m23 = 1; //op.zw
			mvp.m31 = crop.w;
			mvp.m32 = crop.h;
			mvp.m33 = crop.x;
			mvp.m34 = crop.y;
			
			var constantRegisters = new Vector<Float>();
			mvp.toVector(constantRegisters);
			mContext.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.VERTEX, 0, constantRegisters, 3);
			mContext.drawTriangles(mIndexBuffer2.handle, 0, 2);
		}
		else
		{
			var vp = renderer.currentViewProjMat;
			
			var world = renderer.currentVisual.world;
			var model = new Mat44();
			model.tx = world.getTranslate().x;
			model.ty = world.getTranslate().y;
			model.cat(renderer.currentViewProjMat);
			var vp = model;
			
			vp.m13 = 1; //op.zw
			var constantRegisters = new flash.Vector<Float>();
			vp.toVector(constantRegisters);
			
			mContext.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.VERTEX, 0, constantRegisters, 2);
			
			mShader.bindProgram();
			mShader.bindTexture(0, renderer.mNewStage3dTexture.handle);
			
			mContext.drawTriangles(mIndexBuffer.handle, 0, numTiles * 2); //every quad has two triangles
			//renderer.numCallsToDrawTriangle++;
		}
		
		mVertexBuffer.unbind();
	}
}