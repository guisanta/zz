package de.polygonal.zz.render;

import de.polygonal.zz.texture.Texture;
import flash.display.BitmapData;

class RenderTexture extends RenderTarget
{
	public var canvas:BitmapData;
	
	public var alpha:Float = 1;
	
	public function new(width:Int, height:Int)
	{
		super();
		
		mSize.x = width;
		mSize.y = height;
	}
	
	public function initLegacyContext()
	{
		//canvas = new BitmapData(mSize.x, mSize.y, true, (Std.int(alpha * 0xFF) << 24) | color);
		canvas = new BitmapData(mSize.x, mSize.y, true, color);
	}
	
	public function getTexture():Texture
	{
		var t = new de.polygonal.zz.texture.Texture();
		t.setImageData(canvas, true);
		
		return t;
	}
	
	override public function getContext():Dynamic
	{
		return canvas;
	}
	
	override public function configureBackBuffer()
	{
	}
}