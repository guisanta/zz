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
import de.polygonal.ds.Vector;
import de.polygonal.ds.VectorUtil;
import de.polygonal.zz.controller.RepeatType;
import de.polygonal.zz.data.Animation;
import de.polygonal.zz.scene.Spatial;
import haxe.ds.StringMap;

/**
	A simple frame-by-frame animation.
**/
typedef SheetAnimation = Animation<String>;

interface SheetControllerListener
{
	private function onSpriteSheetChangeFrame(frame:String, time:Float, index:Int):Void;
	
	private function onSpriteSheetAniEnd():Void;
}

/**
	A controller for playing back a frame-by-frame animation.
	
	In contrast to the `KeyframeController`, the `SpriteSheetController` doesn't support inbetweens.
**/
@:access(de.polygonal.zz.scene.Spatial)
@:access(de.polygonal.zz.controller.SheetControllerListener)
class SpriteSheetController extends Controller
{
	static var mDataCache:StringMap<AniData> = null;
	
	public var onEnterFrame:Int->String->Bool;
	
	public var currentName(default, null):String = null;
	
	public var currentFrameName(default, null):String;
	
	var mListener:SheetControllerListener;
	var mLastIndex:Int;
	var mCurIndex:Int;
	var mData:AniData;
	
	public var currentAnimation:SheetAnimation;
	
	/**
		Current animation length in seconds.
	**/
	public var length(get_length, never):Float;
	inline function get_length():Float return maxTime;
	
	public var currentFrame(get_currentFrame, never):Int;
	inline function get_currentFrame():Int return mCurIndex;
	
	public function new()
	{
		super();
	}
	
	override public function free()
	{
		mData = null;
		mListener = null;
		super.free();
	}
	
	inline public function setListener(listener:SheetControllerListener)
	{
		mListener = listener;
	}
	
	public function play(def:SheetAnimation, startTime:Float = 0.)
	{
		if (mDataCache == null) mDataCache = new StringMap();
		mData = mDataCache.get(def.name);
		if (mData == null) mDataCache.set(def.name, mData = new AniData(def));
		
		currentAnimation = def;
		
		currentName = def.name;
		
		repeat = def.loop ? RepeatType.Wrap : RepeatType.Clamp;
		passedTime = startTime;
		minTime = 0;
		maxTime = mData.length;
		active = true;
		dispose = false;
		
		mLastIndex = 0;
		mCurIndex = -1;
		
		onUpdate(passedTime);
	}
	
	public function pause()
	{
		active = false;
	}
	
	public function resume()
	{
		assert(mData != null);
		active = true;
	}
	
	public function stop()
	{
		mData = null;
		currentName = null;
		disposeAfterTimeout();
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
			var t0 = t[mLastIndex];
			var t1 = t[mLastIndex + 1];
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
						if (t[i] > controlTime)
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
					index = VectorUtil.bsearchFloat(t, controlTime, 0, k - 1);
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
		if (index != mCurIndex || isLastFrame) //frame changed?
		{
			mCurIndex = index;
			
			currentFrameName = mData.names[index];
			
			mListener.onSpriteSheetChangeFrame(currentFrameName, controlTime, index);
			
			if (isLastFrame)
			{
				mListener.onSpriteSheetAniEnd();
				currentName = null;
				
				currentAnimation = null;
				
				disposeAfterTimeout();
			}
		}
		
		return true;
	}
}

private class AniData
{
	public var totalFrames:Int;
	public var length:Float;
	public var times:Vector<Float>;
	public var names:Vector<String>;
	
	public function new(def:SheetAnimation)
	{
		totalFrames = def.frames.length;
		
		times = new Vector<Float>(totalFrames + 1);
		names = new Vector<String>(totalFrames);
		
		length = 0;
		var i = 0;
		
		var k = def.frames.length;
		while (i < k)
		{
			var frame = def.frames[i];
			
			times[i] = length;
			names[i] = frame.value;
			i++;
			length += frame.holdTime;
		}
		
		times[k] = length;
	}
}