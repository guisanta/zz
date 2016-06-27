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
package de.polygonal.zz.controller;

import de.polygonal.core.util.Assert.assert;
import de.polygonal.ds.ArrayList;
import de.polygonal.ds.tools.NativeArrayTools;
import de.polygonal.zz.controller.RepeatType;
import de.polygonal.zz.data.Animation;
import haxe.ds.StringMap;

/**
	A simple frame-by-frame animation.
**/
typedef SheetAnimation = Animation<String>;

interface SpriteSheetControllerListener
{
	private function onSpriteSheetAniUpdate(frameName:String, time:Float, index:Int):Void;
	private function onSpriteSheetAniFinish():Void;
}

/**
	A controller for playing back a frame-by-frame animation.
	
	In contrast to the `KeyframeController`, the `SpriteSheetController` doesn't support inbetweens.
**/
@:access(de.polygonal.zz.controller.SpriteSheetControllerListener)
class SpriteSheetController extends Controller
{
	static var _dataCache:StringMap<AniData> = null;
	
	public var onFinish:SheetAnimation->Void;
	
	public var repeatCount:Int = 0;
	
	var mListener:SpriteSheetControllerListener;
	var mLastIndex:Int;
	var mCurrentIndex:Int;
	var mCurrentAnimation:SheetAnimation;
	var mData:AniData;
	
	public function new()
	{
		super(TYPE);
	}
	
	override public function free()
	{
		mData = null;
		mListener = null;
		onFinish = null;
		super.free();
	}
	
	inline public function setListener(listener:SpriteSheetControllerListener)
	{
		mListener = listener;
	}
	
	public function play(animation:SheetAnimation, startTime:Float = 0)
	{
		mCurrentAnimation = animation;
		
		if (_dataCache == null)
			_dataCache = new StringMap();
		mData = _dataCache.get(animation.name);
		if (mData == null)
		{
			mData = new AniData(animation);
			_dataCache.set(animation.name, mData);
		}
		
		repeat = animation.loop ? RepeatType.Wrap : RepeatType.Clamp;
		passedTime = startTime;
		minTime = 0;
		maxTime = mData.length;
		active = true;
		dispose = false;
		mCurrentIndex = -1;
		mLastIndex = 0;
		
		onUpdate(passedTime);
	}
	
	public function pause()
	{
		assert(mData != null, "Call play() first.");
		active = false;
	}
	
	public function resume()
	{
		assert(mData != null, "Call play() first.");
		active = true;
	}
	
	public function stop()
	{
		mCurrentAnimation = null;
		mData = null;
		onFinish = null;
		repeatCount = 0;
		markForDisposal();
	}
	
	override function onUpdate(time:Float):Bool
	{
		var controlTime = getControlTime();
		
		var index;
		var k = mData.totalFrames;
		
		if (k == 1)
			index = mLastIndex = 0;
		else
		if (controlTime >= mData.length)
			index = mLastIndex = k - 1;
		else
		{
			index = 0;
			
			var t = mData.times;
			
			//exploit temporal coherence by checking passed time since last invocation
			var t0 = t.get(mLastIndex);
			var t1 = t.get(mLastIndex + 1);
			if (controlTime >= t0 && controlTime <= t1)
				index = mLastIndex;
			else
			{
				if (k < 16)
				{
					//perform sequential search
					var i = 0;
					while (i <= k)
					{
						if (t.get(i) > controlTime)
						{
							index = i - 1;
							break;
						}
						i++;
					}
				}
				else
				{
					//perform binary search
					index = NativeArrayTools.binarySearchf(t.getData(), controlTime, 0, k - 1);
					if (index < 0)
					{
						index = ~index;
						index--;
					}
				}
			}
			
			mLastIndex = index;
		}
		
		var isLastFrame = (repeat == RepeatType.Clamp) && (maxTime - controlTime) <= .01;
		
		if (index != mCurrentIndex || isLastFrame) //frame changed?
		{
			mCurrentIndex = index;
			
			var name = mData.names.get(index);
			
			mListener.onSpriteSheetAniUpdate(name, controlTime, index);
			
			if (isLastFrame)
			{
				mListener.onSpriteSheetAniFinish();
				
				if (repeatCount-- > 0)
				{
					play(mCurrentAnimation, 0);
				}
				else
				{
					if (onFinish != null)
					{
						onFinish(mData.animation);
						onFinish = null;
					}
					
					mData = null;
					markForDisposal();
				}
			}
		}
		
		return true;
	}
}

private class AniData
{
	public var animation:SheetAnimation;
	public var totalFrames:Int;
	public var length:Float = 0;
	public var times:ArrayList<Float>;
	public var names:ArrayList<String>;
	
	public function new(animation:SheetAnimation)
	{
		this.animation = animation;
		
		totalFrames = animation.frames.length;
		
		times = new ArrayList(totalFrames + 1);
		names = new ArrayList(totalFrames);
		
		var i = 0, k = totalFrames, frame;
		while (i < k)
		{
			frame = animation.frames[i++];
			times.unsafePushBack(length);
			names.unsafePushBack(frame.value);
			length += frame.holdTime;
		}
		
		times.unsafePushBack(length);
	}
}