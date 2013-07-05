/*
 *                            _/                                                    _/
 *       _/_/_/      _/_/    _/  _/    _/    _/_/_/    _/_/    _/_/_/      _/_/_/  _/
 *      _/    _/  _/    _/  _/  _/    _/  _/    _/  _/    _/  _/    _/  _/    _/  _/
 *     _/    _/  _/    _/  _/  _/    _/  _/    _/  _/    _/  _/    _/  _/    _/  _/
 *    _/_/_/      _/_/    _/    _/_/_/    _/_/_/    _/_/    _/    _/    _/_/_/  _/
 *   _/                            _/        _/
 *  _/                        _/_/      _/_/
 *
 * POLYGONAL - A HAXE LIBRARY FOR GAME DEVELOPERS
 * Copyright (c) 2012 Michael Baczynski, http://www.polygonal.de
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
package de.polygonal.zz.api.animation;

import haxe.ds.StringMap;

class AniPlayback
{
	public var curAnimationId(default, null):String;
	
	public var curFrame(get_curFrame, never):AniFrame;
	inline function get_curFrame():AniFrame
	{
		if (_curSequence == null)
			return null;
		else
			return _curSequence.getFrameAtTime(_time);
	}
	
	public var finished(get_finished, never):Bool;
	inline function get_finished():Bool
	{
		var s = _curSequence;
		return s != null && !s.loop && _time >= s.length && s.frameCount > 1;
	}
	
	var _curSequence:AniSequence;
	var _time = 0.;
	var _next:StringMap<String>;
	
	public function new()
	{
		_curSequence = null;
	}
	
	public function free():Void
	{
		_curSequence = null;
	}
	
	public function advance(timeDelta:Float):Void
	{
		if (_curSequence == null) return;
		
		_time += timeDelta;
		
		if (_next == null) return;
		
		if (finished && _next.exists(curAnimationId))
			playAnimation(_next.get(curAnimationId));
	}
	
	public function playAnimation(id:String, resetTime = true):Void
	{
		var sequence = AniLib.getAnimation(id);
		if (sequence == null)
		{
			L.w('animation \'$id\' does not exist');
			return;
		}
		
		if (_curSequence != sequence)
		{
			curAnimationId = id;
			_curSequence = sequence;
			if (resetTime) _time = 0;
		}
	}
	
	public function setNext(firstId:String, secondId:String):Void
	{
		if (_next == null) _next = new StringMap();
		_next.set(firstId, secondId);
	}
	
	public function stopAnimation():Void
	{
		curAnimationId = null;
		_curSequence = null;
	}
}