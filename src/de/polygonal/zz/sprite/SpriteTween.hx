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

import de.polygonal.core.tween.ease.Ease;
import de.polygonal.zz.controller.RepeatType;
import de.polygonal.zz.controller.TweenController;
import de.polygonal.zz.controller.TweenController.TweenControllerListener;

enum TweenProperty { X; Y; ScaleX; ScaleY; UniformScale; Rotation; Alpha; }

class SpriteTween implements TweenControllerListener
{
	var mSprite:SpriteBase;
	var mPropertyBits:Int = 0;
	
	public function new(sprite:SpriteBase)
	{
		mSprite = sprite;
	}
	
	public function free()
	{
		stopAll();
		mSprite = null;
	}
	
	public function x(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(X, target, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function y(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(Y, target, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function position(targetX:Float, targetY:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
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
	
	public function scaleX(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(ScaleX, target, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function scaleY(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(ScaleY, target, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function uniformScale(targetScale:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(UniformScale, targetScale, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function rotation(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(Rotation, target, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function alpha(target:Float, duration:Float, ?ease:Ease, ?repeat:RepeatType, ?onFinish:Void->Void):SpriteTween
	{
		tween(Alpha, target, duration, ease, repeat, onFinish);
		
		return this;
	}
	
	public function stop(property:TweenProperty)
	{
		var key = property.getIndex();
		
		if (mPropertyBits & key == 0) return;
		
		var c = mSprite.sgn.controllers;
		while (c != null)
		{
			var next = c.next;
			if (c.type == TweenController.TYPE)
			{
				var tc = c.as(TweenController);
				if (tc.key == key)
				{
					tc.stop();
					tc.setListener(null);
					break;
				}
			}
			c = next;
		}
	}
	
	public function stopAll()
	{
		var c = mSprite.sgn.controllers;
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
		
		mPropertyBits = 0;
	}
	
	function tween(property:TweenProperty, target:Float, duration:Float, ease:Ease, repeat:RepeatType, onFinish:Void->Void):TweenController
	{
		var source =
		switch (property)
		{
			case X: mSprite.x;
			case Y: mSprite.y;
			case ScaleX: mSprite.scaleX;
			case ScaleY: mSprite.scaleY;
			case UniformScale: mSprite.scale;
			case Rotation: mSprite.rotation;
			case Alpha: mSprite.alpha;
		}
		
		var key = property.getIndex();
		
		var c:TweenController = getTweenController(property, duration);
		c.tween(key, source, target, duration, ease == null ? Ease.None : ease);
		c.repeat = repeat == null ? RepeatType.Clamp : repeat;
		c.onFinish = onFinish;
		
		mPropertyBits |= 1 << key;
		
		return c;
	}
	
	function getTweenController(property:TweenProperty, duration:Float):TweenController
	{
		var tc = null;
		
		var key = property.getIndex();
		
		var c = mSprite.sgn.controllers;
		if (c != null)
		{
			if (mPropertyBits & (1 << key) > 0) //try overriding existing controller
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
		mSprite.sgn.attach(tc);
		
		return tc;
	}
	
	/* INTERFACE de.polygonal.zz.controller.TweenController.TweenControllerListener */
	
	function onTweenUpdate(key:Int, val:Float)
	{
		switch (key)
		{
			case 0: mSprite.x = val;
			case 1: mSprite.y = val;
			case 2: mSprite.scaleX = val;
			case 3: mSprite.scaleY = val;
			case 4: mSprite.scale = val;
			case 5: mSprite.rotation = val;
			case 6: mSprite.alpha = val;
		}
	}
	
	/* INTERFACE de.polygonal.zz.controller.TweenController.TweenControllerListener */
	
	function onTweenFinish(key:Int)
	{
		mPropertyBits &= ~(1 << key);
	}
}