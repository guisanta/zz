package de.polygonal.zz.render.platform.flash.legacy;

import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.MovieClip;

/**
	Helper methods for working with the flash display list.
**/
class DisplayListUtil
{
	/**
		Adds `x` to `parent`.
	**/
	inline public static function add(x:DisplayObject, parent:DisplayObjectContainer)
	{
		if (x.parent == null) parent.addChild(x);
	}
	
	/**
		Removes `x` from the display list.
	**/
	inline public static function remove(x:DisplayObject)
	{
		if (x.parent != null) x.parent.removeChild(x);
	}
	
	/**
		Changes the parent of `x` to `parent`.
	**/
	inline public static function changeParent(x:DisplayObject, parent:DisplayObjectContainer)
	{
		remove(x);
		parent.addChild(x);
	}
	
	/**
		Removes all children of `x` from the display list.
	**/
	inline public static function removeChildren(x:DisplayObjectContainer)
	{
		#if debug
		var c = x.numChildren;
		#end
		
		while (x.numChildren > 0)
		{
			x.removeChildAt(0);
			assert(x.numChildren != c, "x.numChildren != c");
		}
	}
	
	/**
		Removes `x` including all children of `x` from the display list.
	**/
	inline public static function removeAll(x:DisplayObjectContainer)
	{
		removeChildren(x);
		remove(x);
	}
	
	/**
		Replaces `x` with `other` by adding `other` to the parent of `x` and
		removing `x` from the display list.
		@throws de.polygonal.core.macro.AssertionError `x` has no parent `(if debug flag ist set`).
	**/
	inline public static function replace(x:DisplayObject, other:DisplayObject)
	{
		assert(x.parent != null, "x.parent != null");
		
		var name = x.name;
		addSibling(x, other);
		remove(x);
		other.name = name;
	}
	
	/**
		Adds `y` to the parent of `x`.
		@throws de.polygonal.core.macro.AssertionError `x` has no parent `(if debug flag ist set`).
	**/
	inline public static function addSibling(x:DisplayObject, y:DisplayObject)
	{
		assert(x.parent != null, "x.parent != null");
		
		x.parent.addChild(y);
	}
	
	/**
		Moves `x` to the foreground.
		@throws de.polygonal.core.macro.AssertionError `x` has no parent `(if debug flag ist set`).
	**/
	inline public static function toFront(x:DisplayObject)
	{
		assert(x.parent != null, "x.parent != null");
		
		return x.parent.setChildIndex(x, x.parent.numChildren - 1);
	}
	
	/**
		Moves `x` to the background.
 	 * @throws de.polygonal.core.macro.AssertionError `x` has no parent `(if debug flag ist set`).
	**/
	inline public static function toBack(x:DisplayObject)
	{
		assert(x.parent != null, "x.parent != null");
		
		return x.parent.setChildIndex(x, 0);
	}
	
	#if flash
	/**
		Moves the playhead of `x` to the previous frame.
		@param wrap Moves the playhead to the last frame once it goes beyond the first frame.
	**/
	inline public static function prevFrame(x:MovieClip, wrap:Bool)
	{
		if (x.currentFrame == 1 && wrap)
			x.gotoAndStop(x.totalFrames);
		else
			x.prevFrame();
	}
	
	/**
		Moves the playhead of `x` to the next frame.
		@param wrap Moves the playhead to the first frame once it goes beyond the last frame.
	**/
	inline public static function nextFrame(mc:MovieClip, wrap:Bool)
	{
		if (mc.currentFrame == mc.totalFrames && wrap)
			mc.gotoAndStop(1);
		else
			mc.nextFrame();
	}
	#end
}