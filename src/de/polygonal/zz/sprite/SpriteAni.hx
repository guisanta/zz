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

import de.polygonal.core.math.Mathematics.M;
import de.polygonal.core.tween.ease.Ease;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.controller.KeyframeController;
import de.polygonal.zz.controller.RepeatType;
import de.polygonal.zz.controller.SpriteSheetController;
import de.polygonal.zz.controller.TweenController;
import de.polygonal.zz.scene.Xform;

/*@:access(de.polygonal.zz.sprite.Sprite)
@:access(de.polygonal.zz.sprite.SpriteAni)
private class Sheet implements SpriteSheetAnimControllerListener
{
	var mController:SpriteSheetController;
	
	var mCurrent(default, null):SpriteSheetAnim;
	
	var mHost:SpriteAni;
	var mLastTime:Float;
	
	public function new(host:SpriteAni)
	{
		mHost = host;
		mLastTime = null;
		//mController = new SpriteSheetController
	}
	
	public function play(animation:SpriteSheetAnim, ?onFinish:SpriteSheetAnim->Void, startOver:Bool = true):SpriteSheetController
	{
		var c = getController();
		c.play(animation, startOver ? 0 : mLastTime);
		//mOnAnimationFinished = onFinish;
		return c;
	}
	
	public function pause(name:String)
	{
		getController().pause();
	}
	
	public function resume(name:String)
	{
		getController().resume();
	}
	
	public function stop()
	{
		var c = getController();
		//mOnAnimationFinished = null;
		c.stop();
		c.setListener(null);
	}
	
	public function getController():SpriteSheetController
	{
		var spatial = mHost.mSprite.mVisual;
		var c:SpriteSheetController = spatial.findControllerOfType(SpriteSheetController.TYPE);
		if (c == null)
		{
			c = new SpriteSheetController();
			spatial.attach(c);
		}
		c.setListener(this);
		return c;
	}
	
	function onSpriteSheetChangeFrame(frame:String, time:Float, index:Int):Void 
	{
		mSprite.frame = frame;
		mLastTime = time;
		//if (onEnterFrame != null) onEnterFrame(frame.index);
	}
	
	function onSpriteSheetAnimFinish():Void 
	{
		if (mOnAnimationFinished != null)
		{
			var c = getSpriteSheetController();
			var f = mOnAnimationFinished;
			mOnAnimationFinished = null;
			//f(c.currentAnim);
		}
	}
	
}*/

enum TweenProperty { X; Y; ScaleX; ScaleY; UniformScale; Rotation; Alpha; }

@:access(de.polygonal.zz.sprite.SpriteBase)
class SpriteAni
	implements SheetControllerListener
	implements TweenControllerListener
	implements KeyframeControllerListener
{
	var mSpriteBase:SpriteBase;
	var mSprite:Sprite;
	
	var mLastTime:Float = 0;
	var mOnAnimationFinished:SheetAnimation->Void;
	
	var mTweenBits:Int;
	
	public function new(spriteBase:SpriteBase)
	{
		mSpriteBase = spriteBase;
		if (Std.is(spriteBase, Sprite)) mSprite = cast(spriteBase, Sprite);
	}
	
	public function free()
	{
		stopTweens();
		
		if (mSprite != null)
		{
			var c = mSprite.getVisual().findControllerOfType(SpriteSheetController.TYPE);
			if (c != null)
			{
				cast(c, SpriteSheetController).stop();
				cast(c, SpriteSheetController).setListener(null);
			}
		}
		
		mOnAnimationFinished = null;
		mSpriteBase = null;
		mSprite = null;
	}
	
	public function getSpriteSheetController():SpriteSheetController
	{
		assert(mSprite != null, "cannot animate a SpriteGroup instance");
		
		var spatial = mSprite.mVisual;
		var c:SpriteSheetController = spatial.findControllerOfType(SpriteSheetController.TYPE);
		if (c == null)
		{
			c = new SpriteSheetController();
			spatial.attach(c);
		}
		c.setListener(this);
		return c;
	}
	
	public function playSpriteSheetAnimation(animation:SheetAnimation, ?onFinish:SheetAnimation->Void, startOver:Bool = true):SpriteSheetController
	{
		var c = getSpriteSheetController();
		c.play(animation, startOver ? 0 : mLastTime);
		mOnAnimationFinished = onFinish;
		return c;
	}
	
	public function pauseSheetAnim(name:String)
	{
		getSpriteSheetController().pause();
	}
	
	public function resumeSheetAnim(name:String)
	{
		getSpriteSheetController().resume();
	}
	
	public function stopSpriteSheetAnimation()
	{
		var c = getSpriteSheetController();
		//mOnAnimationFinished = null;
		c.stop();
		c.setListener(null);
	}
	
	/*	public function defineNextAnimation(first:String, second:String)
	{
		getSpriteSheetController().defineNext(first, second);
	}*/
	
	/*if (mNext != null)
				{
					if (mNext.exists(currentAnim.name)) //play next animation after this one?
					{
						play(mNext.get(currentAnim.name));
						mListener.onSpriteSheetChangeFrame(frame, controlTime, lastFrame);
						return true;
					}
				}*/
				
	/*public function defineNext(first:String, second:String)
	{
		if (mNext == null)
			mNext = new StringMap<String>();
		mNext.set(first, second);
	}*/
	
	function onSpriteSheetChangeFrame(frame:String, time:Float, index:Int):Void 
	{
		mSprite.frame = frame;
		mLastTime = time;
		//if (onEnterFrame != null) onEnterFrame(frame.index);
	}
	
	function onSpriteSheetAniEnd():Void 
	{
		if (mOnAnimationFinished != null)
		{
			var c = getSpriteSheetController();
			
			var f = mOnAnimationFinished;
			mOnAnimationFinished = null;
			f(c.currentAnimation);
		}
	}
	
	public function playKeyframeAnimation(animation:KeyframeAnimation)
	{
		var c = new KeyframeController();
		
		c.play(animation);
		
		c.setListener(this);
		
		var spatial = mSprite.getVisual();
		spatial.attach(c);
		
		c.play(animation, 0);
	}
	
	function onKeyFrameUpdate(xform:Xform)
	{
		mSprite.x = xform.getTranslate().x;
		mSprite.y = xform.getTranslate().y;
		
		mSprite.scaleX = xform.getScale().x;
		mSprite.scaleY = xform.getScale().y;
		
		var angle = xform.getRotate().getAngle() * M.RAD_DEG;
		mSprite.rotation = angle;
	}
	
	public function tweenX(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		tween(X, target, duration, ease, repeat, onFinish);
		return this;
	}
	
	public function tweenY(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		tween(Y, target, duration, ease, repeat, onFinish);
		return this;
	}
	
	public function tweenPosition(targetX:Float, targetY:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		if (onFinish != null)
		{
			var c = 0;
			var f = function() if (++c == 2) onFinish();
			var a = tween(X, targetX, duration, ease, repeat, f);
			var b = tween(Y, targetY, duration, ease, repeat, f);
		}
		else
		{
			tween(X, targetX, duration, ease, repeat, onFinish);
			tween(Y, targetY, duration, ease, repeat, onFinish);
		}
		
		return this;
	}
	
	public function tweenScaleX(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		tween(ScaleX, target, duration, ease, repeat, onFinish);
		return this;
	}
	
	public function tweenScaleY(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		tween(ScaleY, target, duration, ease, repeat, onFinish);
		return this;
	}
	
	public function tweenUniformScale(targetScale:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		if (onFinish != null)
		{
			var c = 0;
			var f = function() if (++c == 2) onFinish();
			var a = tween(ScaleX, targetScale, duration, ease, repeat, f);
			var b = tween(ScaleY, targetScale, duration, ease, repeat, f);
		}
		else
		{
			tween(ScaleX, targetScale, duration, ease, repeat, onFinish);
			tween(ScaleY, targetScale, duration, ease, repeat, onFinish);
		}
		
		return this;
	}
	
	public function tweenRotation(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		tween(Rotation, target, duration, ease, repeat, onFinish);
		return this;
	}
	
	public function tweenAlpha(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteAni
	{
		tween(Alpha, target, duration, ease, repeat, onFinish);
		return this;
	}
	
	public function stopTweens()
	{
		var c = mSpriteBase.sgn.controllers;
		while (c != null)
		{
			var next = c.next;
			if (c.type == TweenController.TYPE)
			{
				var tc = c.as(TweenController);
				tc.stop();
				tc.setListener(null);
			}
			c = next;
		}
		
		mTweenBits = 0;
	}
	
	function tween(property:TweenProperty, target:Float, duration:Float, ease:Ease, repeat:RepeatType, onFinish:Void->Void):TweenController
	{
		var source =
		switch (property)
		{
			case X: mSpriteBase.x;
			case Y: mSpriteBase.y;
			case ScaleX: mSpriteBase.scaleX;
			case ScaleY: mSpriteBase.scaleY;
			case UniformScale: mSpriteBase.scale;
			case Rotation: mSpriteBase.rotation;
			case Alpha: mSpriteBase.alpha;
		}
		
		var key = property.getIndex();
		
		var c:TweenController = getTweenController(property, duration);
		c.tween(key, source, target, duration, ease == null ? Ease.None : ease);
		c.repeat = repeat == null ? RepeatType.Clamp : repeat;
		c.onFinish = onFinish;
		
		mTweenBits |= 1 << key;
		
		return c;
	}
	
	function getTweenController(property:TweenProperty, duration:Float):TweenController
	{
		var tc = null;
		
		var key = property.getIndex();
		
		var c = mSpriteBase.sgn.controllers;
		if (c != null)
		{
			if (mTweenBits & (1 << key) > 0) //try overriding existing controller
			{
				while (c != null)
				{
					if (c.type == TweenController.TYPE)
					{
						tc = c.as(TweenController);
						if (tc.key == key)
						{
							tc.setListener(this);
							
							return tc;
						}
					}
					c = c.next;
				}
			}
			else
			{
				//reuse existing inactive controller
				while (c != null)
				{
					if (c.type == TweenController.TYPE && !c.active)
					{
						tc = cast c;
						tc.setListener(this);
						
						return tc;
					}
					c = c.next;
				}
			}
		}
		
		//can't reuse/override existing controller; create a new one
		tc = new TweenController();
		tc.setListener(this);
		mSpriteBase.sgn.attach(tc);
		
		return tc;
	}
	
	/* INTERFACE de.polygonal.zz.controller.TweenController.TweenControllerListener */
	
	function onTweenUpdate(key:Int, val:Float)
	{
		switch (key)
		{
			case 0: mSpriteBase.x = val;
			case 1: mSpriteBase.y = val;
			case 2: mSpriteBase.scaleX = val;
			case 3: mSpriteBase.scaleY = val;
			case 4: mSpriteBase.scale = val;
			case 5: mSpriteBase.rotation = val;
			case 6: mSpriteBase.alpha = val;
		}
	}
	
	/* INTERFACE de.polygonal.zz.controller.TweenController.TweenControllerListener */
	
	function onTweenFinish(key:Int)
	{
		mTweenBits &= ~(1 << key);
	}
}