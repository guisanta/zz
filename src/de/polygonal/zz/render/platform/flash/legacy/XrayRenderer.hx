package de.polygonal.zz.render.platform.flash.legacy;

import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.math.Vec3;
import de.polygonal.zz.render.effect.ColorEffect;
import de.polygonal.zz.render.effect.TextureEffect;
import de.polygonal.zz.render.Renderer;
import de.polygonal.zz.scene.BoxBv;
import de.polygonal.zz.scene.Spatial;
import de.polygonal.zz.scene.Xform;
import flash.display.Graphics;
import flash.display.JointStyle;

@:access(de.polygonal.zz.scene.Spatial)
class XrayRenderer extends Renderer
{
	var mContext:Graphics;
	
	public function new()
	{
		super();
		
		supportsNonPowerOfTwoTextures = true;
	}
	
	override function onInitRenderContext(value:Dynamic)
	{
		#if debug
		try
		{
			mContext = untyped value.graphics;
		}
		catch(error:Dynamic)
		{
			throw "invalid context: no flash.display.Graphics object found";
		}
		#else
		mContext = untyped value.graphics;
		#end
	}
	
	override function clear()
	{
		var target = getRenderTarget();
		if (target == null || mContext == null) return;
		
		mContext.clear();
		
		var alpha = target.color >>> 24;
		if (alpha > 0)
		{
			mContext.beginFill(target.color & 0xFFFFFF, alpha / 0xFF);
			var v = target.getPixelViewport();
			mContext.drawRect(0, 0,v.w, v.h);
			mContext.endFill();
		}
		
		//mViewport = target.getPixelViewport();
	}
	
	override function drawColorEffect(effect:ColorEffect)
	{
		
	}
	
	override function drawTextureEffect(effect:TextureEffect)
	{
		//triangles
		setModelViewProjMatrix(currentVisual);
		
		var vertices = [];
		vertices[0] = clipToScreenSpace(currentMvp.timesVector(new Vec3(0, 0)));
		vertices[1] = clipToScreenSpace(currentMvp.timesVector(new Vec3(1, 0)));
		vertices[2] = clipToScreenSpace(currentMvp.timesVector(new Vec3(1, 1)));
		vertices[3] = clipToScreenSpace(currentMvp.timesVector(new Vec3(0, 1)));
		var indices = [0, 1, 2, 0, 2, 3];
		var i = 0;
		var k = 6;
		while (i < k)
		{
			var a = vertices[indices[i++]];
			var b = vertices[indices[i++]];
			var c = vertices[indices[i++]];
			
			mContext.lineStyle(0, 0x000000, .5);
			drawPolyline([a, b, c], 3);
		}
		
		//origin
		var v = modelToScreenSpace(currentVisual.world, new Vec3(0, 0));
		drawVertex(v.x, v.y);
		
		//bounding volume
		drawWorldBv(currentVisual);
	}
	
	override function getProjectionMatrix():Mat44
	{
		mProjMatrix.setAsIdentity();
		
		//default projection space is from [-1,1]
		var c = getCamera();
		
		if (c != null)
		{
			//projection components
			mProjMatrix.m11 = 2 / c.sizeX;
			mProjMatrix.m22 = 2 / c.sizeY;
		}
		else
		{
			mProjMatrix.tx = -1;
			mProjMatrix.ty = 1;
			
			//projection components
			var s = getRenderTarget().getSize();
			mProjMatrix.m11 = 2 / s.x;
			mProjMatrix.m22 = 2 / s.y;
		}
		
		//flip y-axis
		mProjMatrix.m22 *= -1; 
		
		return mProjMatrix;
	}
	
	override function onBeginScene()
	{
		super.onBeginScene();
		
		/*for (i in TreeUtil.descendants(mCurSceneRoot))
			if (i.isNode()) drawWorldBv(i);
		
		for (i in TreeUtil.descendants(mCurSceneRoot))
		{
			var c = modelToScreenSpace(i.world, new Vec3());
			var p = modelToScreenSpace(i.parent.world, new Vec3());
			
			var dx = c.x - p.x;
			var dy = c.y - p.y;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist < 10) continue;
			
			dx /= dist;
			dy /= dist;
			
			c.x -= dx * 5;
			c.y -= dy * 5;
			p.x += dx * 5;
			p.y += dy * 5;
			
			mContext.lineStyle(0, 0, .25);
			drawLine(c, p);
		}*/
	}
	
	override function onEndScene()
	{
		var viewport = mRenderTarget.getPixelViewport();
		
		mContext.lineStyle(0, 0x00FFFF, 1, false, JointStyle.MITER);
		mContext.drawRect(viewport.x, viewport.y, viewport.w, viewport.h);
		
		super.onEndScene();
	}
	
	
	
	
	
	
	
	
	
	
	function modelToScreenSpace(world:Xform, point:Vec3):Coord2f
	{
		world.applyForward(point, point);
		
		return worldToScreenSpace(point);
	}
	
	function worldToScreenSpace(point:Vec3):Coord2f
	{
		currentViewProjMat.timesVectorConst(point, point);
		return clipToScreenSpace(point);
	}
	
	function clipToScreenSpace(input:Vec3):Coord2f
	{
		var viewport = mRenderTarget.getPixelViewport();
		var x = (input.x + 1) * (viewport.w / 2) + viewport.x;
		var y = (1 - input.y) * (viewport.h / 2) + viewport.y; //flip y
		return new Coord2f(x, y);
	}
	
	function drawVertex(x:Float, y:Float)
	{
		mContext.lineStyle(Math.NaN);
		mContext.beginFill(0, 1);
		mContext.drawRect(x - 2, y - 2, 4, 4);
		mContext.endFill();
	}
	
	function drawLine(a:Coord2f, b:Coord2f)
	{
		mContext.moveTo(a.x, a.y);
		mContext.lineTo(b.x, b.y);
	}
	
	function drawPolyline(vertices:Array<Coord2f>, k:Int)
	{
		var i = 0;
		
		var v0 = vertices[i++];
		mContext.moveTo(v0.x, v0.y);
		
		while (i < k)
		{
			var v1 = vertices[i++];
			mContext.lineTo(v1.x, v1.y);
		}
		
		mContext.lineTo(v0.x, v0.y);
	}
	
	function drawWorldBv(spatial:Spatial)
	{
		mContext.lineStyle(0, 0x0080FF, 0.5);
		
		switch (spatial.worldBound.type)
		{
			case BvType.Circle:
				var c = spatial.worldBound.center;
				var r = spatial.worldBound.radius;
				var steps = 90;
				var vertices = [];
				for (i in 0...steps)
				{
					var angle = i * (M.PI2 / steps);
					var x = c.x + Math.cos(angle) * r;
					var y = c.y + Math.sin(angle) * r;
					var w = worldToScreenSpace(new Vec3(x, y));
					vertices[i] = w;
				}
				drawPolyline(vertices, steps);
				
			case BvType.Box:
				var o:BoxBv = cast spatial.worldBound;
				var a = worldToScreenSpace(new Vec3(o.minX, o.minY));
				var b = worldToScreenSpace(new Vec3(o.maxX, o.minY));
				var c = worldToScreenSpace(new Vec3(o.maxX, o.maxY));
				var d = worldToScreenSpace(new Vec3(o.minX, o.maxY));
				drawPolyline([a, b, c, d], 4);
		}
	}
}