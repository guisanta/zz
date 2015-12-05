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

import de.polygonal.zz.controller.KeyframeController;
import de.polygonal.zz.controller.KeyframeController.KeyframeAnimation;
import de.polygonal.zz.controller.KeyframeController.KeyframeControllerListener;

class SpriteKeyframeAni implements KeyframeControllerListener
{
	var mSprite:SpriteBase;
	var mController:KeyframeController;
	
	public function new(sprite:SpriteBase)
	{
		mSprite = sprite;
	}
	
	public function free()
	{
		if (mController != null) mController.free();
		mController = null;
	}
	
	public function play(animation:KeyframeAnimation, ?startTime:Float = 0, ?onFinish:Void->Void)
	{
		var c = mController;
		if (c == null || c.type == -1)
		{
			c = mController = new KeyframeController();
			c.setListener(this);
			mSprite.sgn.attach(c);
		}
		
		c.onFinish = onFinish;
		c.play(animation, startTime);
	}
	
	public function stop(reset = true)
	{
		var c = mController;
		if (c != null && c.type != -1)
		{
			if (reset) c.setKeyframe(0);
			c.stop();
		}
	}
	
	function onKeyframeUpdate(keyValues:KeyValues)
	{
		mSprite.scaleX = keyValues.scaleX;
		mSprite.scaleY = keyValues.scaleY;
		mSprite.rotation = keyValues.rotation;
		mSprite.x = keyValues.translateX;
		mSprite.y = keyValues.translateY;
		mSprite.alpha = keyValues.alpha;
	}
}