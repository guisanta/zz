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
package de.polygonal.zz.sprite;

import de.polygonal.core.math.random.Random;
import de.polygonal.zz.controller.SpriteSheetController;
import de.polygonal.zz.controller.SpriteSheetController.SpriteSheetControllerListener;
import de.polygonal.zz.data.Animation.AnimationFrame;

class SpriteSheetAni implements SpriteSheetControllerListener
{
	public static function createSequence(frameName:String, minIndex:Int, maxIndex:Int):Array<String>
	{
		var output = [];
		
		inline function add(i:Int) output.push(frameName + (i < 10 ? "000" : (i < 100 ? "00" : "0")) + i);
		
		var i = minIndex;
		if (minIndex > maxIndex)
		{
			while (i >= maxIndex) add(i--);
		}
		else
		{
			while (i <= maxIndex) add(i++);
		}
		return output;
	}
	
	public static function createAnimation(name:String, frames:Array<String>, holdTime:Float, loop:Bool):SheetAnimation
	{
		var frames = [for (i in 0...frames.length) new AnimationFrame(frames[i], holdTime)];
		return new SheetAnimation(name, loop, frames);
	}
	
	/**
		Current animation length in seconds or -1 if no animation is playing.
	**/
	public var length(default, null):Float = -1;
	
	var mController:SpriteSheetController = null;
	var mSprite:Sprite;
	var mLastTime:Float = 0;
	var mCurrentAnimation:SheetAnimation;
	
	public function new(sprite:Sprite)
	{
		mSprite = sprite;
	}
	
	public function free()
	{
		if (mController != null)
		{
			mController.free();
			mController = null;
		}
		mSprite = null;
	}
	
	public function play(animation:SheetAnimation, ?startOver:Bool = true, ?onFinish:SheetAnimation->Void):SpriteSheetAni
	{
		mCurrentAnimation = animation;
		var c = getController();
		c.play(animation, startOver ? 0 : mLastTime);
		c.onFinish = onFinish;
		length = c.maxTime;
		return this;
	}
	
	public function repeat(times:Int):SpriteSheetAni
	{
		var c = getController();
		c.repeatCount = times;
		return this;
	}
	
	public function pause():SpriteSheetAni
	{
		getController().pause();
		return this;
	}
	
	public function resume():SpriteSheetAni
	{
		getController().resume();
		return this;
	}
	
	public function stop():SpriteSheetAni
	{
		getController().stop();
		length = -1;
		mCurrentAnimation = null;
		return this;
	}
	
	public function randomizeTime():SpriteSheetAni
	{
		assert(mCurrentAnimation != null, "Call play() first.");
		getController().passedTime = Random.frandRange(0, length);
		return this;
	}
	
	function getController():SpriteSheetController
	{
		if (mController == null || mController.type < 0)
		{
			var spatial = mSprite.sgn;
			var c:SpriteSheetController = spatial.findControllerOfType(SpriteSheetController.TYPE);
			if (c == null)
			{
				c = new SpriteSheetController();
				spatial.attach(c);
			}
			c.setListener(this);
			mController = c;
		}
		
		return mController;
	}
	
	/* INTERFACE de.polygonal.zz.controller.SpriteSheetController.SpriteSheetControllerListener */
	
	@:access(de.polygonal.zz.sprite.Sprite)
	function onSpriteSheetAniUpdate(frame:String, time:Float, index:Int)
	{
		mLastTime = time;
		mSprite.frame = frame;
	}
	
	/* INTERFACE de.polygonal.zz.controller.SpriteSheetController.SpriteSheetControllerListener */
	
	function onSpriteSheetAniFinish()
	{
		length = -1;
		mCurrentAnimation = null;
	}
}