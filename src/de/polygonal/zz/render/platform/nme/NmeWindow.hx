package de.polygonal.zz.render.platform.nme;

import de.polygonal.ds.Graph;
import nme.Lib;
import de.polygonal.core.math.Coord2.Coord2i;
import nme.app.Application;
import nme.display.Graphics;
import nme.display.Shape;
import nme.events.Event;

          //stage.quality = nme.display.StageQuality.LOW;
          //stage.quality = nme.display.StageQuality.MEDIUM;
          //stage.quality = nme.display.StageQuality.HIGH;
          //stage.quality = nme.display.StageQuality.BEST;

@:access(de.polygonal.zz.render.RenderWindowListener)
@:access(de.polygonal.zz.render.Renderer)
class NmeWindow extends RenderWindow
{
	public static function create(onCreate:Void->Void)
	{
		var flags = Lib.HARDWARE | Lib.RESIZABLE;
		nme.Lib.create(onCreate, 640, 480, 60, 0xcccccc, flags);
	}
	
	var mGraphics:Graphics;
	
	public function new(listener:RenderWindowListener)
	{
		super(listener);
		
		Lib.stage.align = nme.display.StageAlign.TOP_LEFT;
		Lib.stage.scaleMode = nme.display.StageScaleMode.NO_SCALE;
		Lib.stage.addEventListener(Event.RESIZE, onResize);
	}
	
	function onResize(e:Event):Void
	{
		resize(Lib.stage.stageWidth, Lib.stage.stageHeight);
	}
	
	public function initContext()
	{
		//var flags = 0;
		//flags |= Lib.HARDWARE;
		//flags |= Lib.RESIZABLE;
		//flags |= Lib.FULLSCREEN;
		
		var width = nme.Lib.stage.stageWidth;
		var height = nme.Lib.stage.stageHeight;
		
		//Application.nmeWindow.
		
		mSize.set(width, height);
		
		var shape = new Shape();
		
		mGraphics = shape.graphics;
		
		Lib.stage.addChild(shape);
		
		mListener.onContext();
	}
	
	public function enableRightMouseButton()
	{
	}
	
	override public function free()
	{
		super.free();
	}
	
	override public function getContext():Dynamic
	{
		return mGraphics;
	}
	
	override public function showCursor()
	{
	}
	
	override public function hideCursor()
	{
	}
	
	override public function hideContextMenu()
	{
	}
	
	override public function isFullscreen():Bool
	{
		return false;
	}
	
	override public function isFullscreenSupported():Bool
	{
		return false;
	}
	
	override public function enterFullscreen()
	{
		//stage.displayState = (stage.displayState==StageDisplayState.NORMAL) ?
              //StageDisplayState.FULL_SCREEN : StageDisplayState.NORMAL;
	}
	
	override public function leaveFullscreen()
	{
	}
	
	override function configureBackBuffer()
	{
	}
}