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
import de.polygonal.ds.IntIntHashTable;
import de.polygonal.zz.controller.KeyframeController;
import de.polygonal.zz.controller.RepeatType;
import de.polygonal.zz.controller.SpriteSheetController;
import de.polygonal.zz.controller.TweenController;
import de.polygonal.zz.scene.Xform;
import haxe.ds.IntMap;
import haxe.ds.StringMap;

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

//private class Tweening


@:build(de.polygonal.core.macro.IntConsts.build(
[
	TWEEN_X, TWEEN_Y,
	TWEEN_SCALE_X, TWEEN_SCALE_Y, TWEEN_SCALE,
	TWEEN_ROTATION,
	TWEEN_ALPHA
], true, false))
@:access(de.polygonal.zz.sprite.SpriteBase)
class SpriteAni
	implements SheetControllerListener
	implements TweenControllerListener
	implements KeyframeControllerListener
{
	public static function print():String
	{
		var s = "";
		s += 'TWEEN_X=$TWEEN_X\n';
		s += 'TWEEN_Y=$TWEEN_Y\n';
		s += 'TWEEN_SCALE_X=$TWEEN_SCALE_X\n';
		s += 'TWEEN_SCALE_Y=$TWEEN_SCALE_Y\n';
		s += 'TWEEN_SCALE=$TWEEN_SCALE\n';
		s += 'TWEEN_ROTATION=$TWEEN_ROTATION\n';
		s += 'TWEEN_ALPHA=$TWEEN_ALPHA\n';
		return s;
	}
	
	static var mPropertyMap:IntIntHashTable;
	static var mCallbackMap:IntMap<Void->Void>;
	
	var mSpriteBase:SpriteBase;
	var mSprite:Sprite;
	
	var mLastTime:Float = 0;
	var mOnAnimationFinished:SheetAnimation->Void;
	
	public function new(spriteBase:SpriteBase)
	{
		mSpriteBase = spriteBase;
		if (Std.is(spriteBase, Sprite)) mSprite = cast(spriteBase, Sprite);
		
		if (mPropertyMap == null)
		{
			mPropertyMap = new IntIntHashTable(4096, 4096, false);
			mCallbackMap = new IntMap();
		}
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
	
	public var onEnterFrame:Int->Void;
	
	
	

	
	public function getTweenBuilder():TweenBuilder
		return new TweenBuilder(this);
	
	public function tweenX(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
		tween(TWEEN_X, target, duration, ease, repeat, onFinish);
	
	public function tweenY(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
		tween(TWEEN_Y, target, duration, ease, repeat, onFinish);
	
	public function tweenXY(targetX:Float, targetY:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
	{
		if (onFinish != null)
		{
			var c = 0;
			var f = function() if (++c == 2) onFinish();
			
			var a = tween(TWEEN_X, targetX, duration, ease, repeat, f);
			var b = tween(TWEEN_Y, targetY, duration, ease, repeat, f);
		}
		else
		{
			tween(TWEEN_X, targetX, duration, ease, repeat, onFinish);
			tween(TWEEN_Y, targetY, duration, ease, repeat, onFinish);
		}
	}
	
	public function tweenScaleX(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
		tween(TWEEN_SCALE_X, target, duration, ease, repeat, onFinish);
	
	public function tweenScaleY(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
		tween(TWEEN_SCALE_Y, target, duration, ease, repeat, onFinish);
	
	public function tweenScale(targetScale:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
	{
		if (onFinish != null)
		{
			var c = 0;
			var f = function() if (++c == 2) onFinish();
			
			var a = tween(TWEEN_SCALE_X, targetScale, duration, ease, repeat, f);
			var b = tween(TWEEN_SCALE_Y, targetScale, duration, ease, repeat, f);
		}
		else
		{
			tween(TWEEN_SCALE_X, targetScale, duration, ease, repeat, onFinish);
			tween(TWEEN_SCALE_Y, targetScale, duration, ease, repeat, onFinish);
		}
	}
	
	public function tweenRotation(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
		tween(TWEEN_ROTATION, target, duration, ease, repeat, onFinish);
	
	public function tweenAlpha(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void)
		tween(TWEEN_ALPHA, target, duration, ease, repeat, onFinish);
	
	public function stopTweens()
	{
		var c = mSpriteBase.sgn.controllers;
		while (c != null)
		{
			var next = c.next;
			if (c.type == TweenController.TYPE)
			{
				var tc:TweenController = cast c;
				var id = tc.id;
				mPropertyMap.clr(id);
				mCallbackMap.remove(id);
				tc.stop();
				tc.setListener(null);
			}
			c = next;
		}
	}
	
	function onTweenUpdate(id:Int, value:Float)
	{
		var property = mPropertyMap.get(id);
		switch (property)
		{
			case TWEEN_X: 
				
				//mSpriteBase.xSmooth(value);
				mSpriteBase.x = value;
			
			case TWEEN_Y:
				
				//mSpriteBase.ySmooth(value);
				mSpriteBase.y = value;
			
			case TWEEN_SCALE_X:
				//mSpriteBase.scaleXSmooth(value);
				mSpriteBase.scaleX = value;
			
			case TWEEN_SCALE_Y:
				//mSpriteBase.scaleYSmooth(value);
				mSpriteBase.scaleY = value;
			
			case TWEEN_SCALE:
				mSpriteBase.scale = mSpriteBase.scaleY = value;
			
			case TWEEN_ROTATION: mSpriteBase.rotation = value;
			case TWEEN_ALPHA:    mSpriteBase.alpha = value;
		}
	}
	
	function onTweenFinish(id:Int)
	{
		var property = mPropertyMap.get(id);
		mPropertyMap.clr(id);
		
		/*switch (property)
		{
			case TWEEN_X: 
				mSpriteBase.x0 = mSpriteBase.x1;
			
			case TWEEN_Y: 
				mSpriteBase.y0 = mSpriteBase.y1;
				
			case TWEEN_SCALE_X:
				mSpriteBase.scaleX0 = mSpriteBase.scaleX1;
				
			case TWEEN_SCALE_Y:
				mSpriteBase.scaleY0 = mSpriteBase.scaleY1;
		}*/
		
		var func = mCallbackMap.get(id);
		if (func != null)
		{
			mCallbackMap.remove(id);
			func();
		}
	}
	
	function tween(property:Int, target:Float, duration:Float, ease:Ease, repeat:RepeatType, onFinish:Void->Void):TweenController
	{
		var source =
		switch (property)
		{
			case TWEEN_X: mSpriteBase.x;
			case TWEEN_Y: mSpriteBase.y;
			case TWEEN_SCALE_X: mSpriteBase.scaleX;
			case TWEEN_SCALE_Y: mSpriteBase.scaleY;
			case TWEEN_SCALE: mSpriteBase.scale;
			case TWEEN_ROTATION: mSpriteBase.rotation;
			case TWEEN_ALPHA: mSpriteBase.alpha;
			case _: throw "invalid property";
		}
		
		if (ease == null) ease = Ease.None;
		
		var c:TweenController = getTweenController(property, duration);
		c.tween(source, target, duration, ease);
		c.repeat = repeat == null ? RepeatType.Clamp : repeat;
		
		mPropertyMap.setIfAbsent(c.id, property); //don't create duplicate entries when overriding controller
		
		if (onFinish != null) mCallbackMap.set(c.id, onFinish);
		
		return c;
	}
	
	function getTweenController(property:Int, duration:Float):TweenController
	{
		var tc:TweenController = null;
		
		var c = mSpriteBase.sgn.controllers;
		if (c != null) //there are controllers
		{
			if (mPropertyMap.has(property))
			{
				//override existing controller
				while (c != null)
				{
					if (c.type == TweenController.TYPE)
					{
						tc = cast c;
						if (mPropertyMap.get(tc.id) == property)
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
}

@:access(de.polygonal.zz.sprite.SpriteAni)
private class TweenBuilder
{
	static var mFlagLookup:StringMap<Int>;
	
	var mAnim:SpriteAni;
	var mDuration:Float;
	var mProperty:String;
	var mTarget:Float;
	var mEase:Ease;
	var mRepeat:RepeatType;
	
	public function new(anim:SpriteAni)
	{
		mAnim = anim;
		reset();
		
		if (mFlagLookup == null)
		{
			mFlagLookup = new StringMap<Int>();
			mFlagLookup.set("x", SpriteAni.TWEEN_X);
			mFlagLookup.set("y", SpriteAni.TWEEN_Y);
			mFlagLookup.set("sx", SpriteAni.TWEEN_SCALE_X);
			mFlagLookup.set("sy", SpriteAni.TWEEN_SCALE_Y);
			mFlagLookup.set("scale", SpriteAni.TWEEN_SCALE);
			mFlagLookup.set("rotation", SpriteAni.TWEEN_ROTATION);
			mFlagLookup.set("alpha", SpriteAni.TWEEN_ALPHA);
		}
	}
	
	inline public function prop(name:String):TweenBuilder
	{
		assert(~/x|y|sx|sy|rotation|alpha|scale/.match(name), "invalid property name");
		mProperty = name;
		return this;
	}
	
	inline public function dur(seconds:Float):TweenBuilder
	{
		mDuration = seconds;
		return this;
	}
	
	inline public function ease(ease:Ease):TweenBuilder
	{
		mEase = ease;
		return this;
	}
	
	inline public function val(value:Float):TweenBuilder
	{
		mTarget = value;
		return this;
	}
	
	inline public function wrap():TweenBuilder
	{
		mRepeat = RepeatType.Wrap;
		return this;
	}
	
	inline public function cycle():TweenBuilder
	{
		mRepeat = RepeatType.Cycle;
		return this;
	}
	
	inline public function clamp():TweenBuilder
	{
		mRepeat = RepeatType.Clamp;
		return this;
	}
	
	public function run(?onFinish:Void->Void):TweenBuilder
	{
		assert(mProperty != null, "property missing");
		assert(!Math.isNaN(mTarget), "target value missing");
		assert(!Math.isNaN(mDuration), "duration missing");
		
		mAnim.tween(mFlagLookup.get(mProperty), mTarget, mDuration, mEase, mRepeat, onFinish);
		return this;
	}
	
	public function reset()
	{
		mProperty = null;
		mDuration = Math.NaN;
		mTarget = Math.NaN;
		mEase = Ease.None;
		mRepeat = RepeatType.Clamp;
	}
}