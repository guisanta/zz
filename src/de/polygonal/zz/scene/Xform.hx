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
package de.polygonal.zz.scene;

import de.polygonal.core.math.Coord2.Coord2f;
import de.polygonal.core.math.Mat33;
import de.polygonal.core.math.Mat44;
import de.polygonal.core.math.Vec3;
import de.polygonal.core.util.Assert.assert;
import de.polygonal.core.math.Mathematics as M;
import haxe.ds.Vector;

/**
	Represents an affine transformation Y = M*X+T where M is a 3x3 matrix and T is a translation vector.
	
	- to support general affine transforms, M can be any invertible 3x3 matrix.
	- the vector X is transformed in the "forward" direction to Y.
	- the "inverse" direction transforms Y to X (X = M^{-1}*(Y-T) in the general case.
	- when M = R*S, the inverse direction is X = S^{-1}*R^{T}*(Y-T).
	- in most cases, M = R, a rotation matrix, or M = R*S where R is a rotation matrix and S is a diagonal matrix whose diagonal entries are positive scales.
	- all set* functions set the is-identity hint to false.
	- setRotate() sets the is-rsmatrix hint to true. If false, getRotate() fires an "assert" in debug mode.
	- setMatrix() sets the is-rsmatrix and is-uniform-scale hints to false.
	- setScale() sets the is-uniform-scale hint to false.
	- setUniformScale() sets the is-uniform-scale hint to true. If false, getUniformScale() fires an "assert" in debug mode.
**/
@:build(de.polygonal.core.macro.IntConsts.build(
[
	HINT_IDENTITY, HINT_RS_MATRIX, HINT_UNIT_SCALE, HINT_UNIFORM_SCALE, HINT_IDENTITY_ROTATION, HINT_HMATRIX_DIRTY, HINT_INVERSE_DIRTY
], true, false))
@:access(de.polygonal.zz.scene.Node)
class Xform
{
	static var _tmpMat1 = new Mat33();
	static var _tmpMat2 = new Mat33();
	
	var mScale:Vec3;
	var mMatrix:Mat33;
	var mTranslate:Vec3;
	var mHints:Int;
	
	public function new()
	{
		mScale = new Vec3(1, 1, 1);
		mTranslate = new Vec3(0, 0, 0);
		mMatrix = new Mat33();
		mHints = HINT_IDENTITY | HINT_RS_MATRIX | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE;
		setIdentity();
	}
	
	public function free()
	{
		mScale = null;
		mTranslate = null;
		mMatrix = null;
	}
	
	/**
		Hint about the structure of the transformation.
		Returns true if transformation defines I.
	**/
	inline public function isIdentity():Bool return mHints & HINT_IDENTITY > 0;
	
	/**
		Hint about the structure of the transformation.
		Returns true if transformation defines R*S.
	**/
	inline public function isRSMatrix():Bool return mHints & HINT_RS_MATRIX > 0;
	
	/**
		Hint about the structure of the transformation.
		Returns true if transformation defines R*S, S = c*I.
	**/
	inline public function isUniformScale():Bool return mHints & HINT_UNIFORM_SCALE > 0;
	
	/**
		Hint about the structure of the transformation.
		Returns true if transformation defines S = I.
	**/
	inline public function isUnitScale():Bool return mHints & HINT_UNIT_SCALE > 0;
	
	/**
		Hint about the structure of the transformation.
		Returns true if R = I.
	**/
	inline public function isIdentityRotation():Bool return mHints & HINT_IDENTITY_ROTATION > 0;
	
	inline public function getScale():Vec3
	{
		assert(isRSMatrix(), "matrix is not a rotation-scale");
		
		return mScale;
	}
	
	inline public function setScale(x:Float, y:Float, z:Float)
	{
		assert(isRSMatrix(), "matrix is not a rotation");
		assert(x != 0 && y != 0 && z != 0, "scales must be non-zero");
		mScale.x = x;
		mScale.y = y;
		mScale.z = z;
		mHints &= ~(HINT_IDENTITY | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE);
		mHints |= HINT_HMATRIX_DIRTY;
	}
	
	inline public function setScale2(x:Float, y:Float)
	{
		assert(isRSMatrix(), "matrix is not a rotation");
		assert(x != 0 && y != 0, "scales must be non-zero");
		mScale.x = x;
		mScale.y = y;
		mHints &= ~(HINT_IDENTITY | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE);
		mHints |= HINT_HMATRIX_DIRTY;
	}
	
	inline public function getUniformScale():Float
	{
		assert(isRSMatrix(), "matrix is not a rotation-scale");
		assert(isUniformScale(), "scales are not uniform");
		
		return mScale.x;
	}
	
	inline public function setUniformScale(scale:Float)
	{
		assert(isRSMatrix(), "matrix is not a rotation");
		assert(scale != 0, "scale must be non-zero");
		mScale.x = mScale.y = mScale.z = scale;
		mHints &= ~(HINT_IDENTITY | HINT_UNIT_SCALE);
		mHints |= HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
	}
	
	inline public function setUniformScale2(scale:Float)
	{
		assert(isRSMatrix(), "matrix is not a rotation");
		assert(scale != 0, "scale must be non-zero");
		mScale.x = mScale.y = scale;
		mHints &= ~(HINT_IDENTITY | HINT_UNIT_SCALE);
		mHints |= HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
	}
	
	inline public function getRotate():Mat33
	{
		assert(isRSMatrix(), "matrix is not a rotation");
		
		return mMatrix;
	}
	
	inline public function setRotate(rotate:Mat33)
	{
		if (mMatrix != rotate) mMatrix.of(rotate);
		mHints &= ~(HINT_IDENTITY | HINT_IDENTITY_ROTATION);
		mHints |= HINT_RS_MATRIX | HINT_HMATRIX_DIRTY;
	}
	
	inline public function setIdentityRotation()
	{
		mMatrix.setIdentity();
		mHints |= HINT_RS_MATRIX | HINT_IDENTITY_ROTATION | HINT_HMATRIX_DIRTY;
	}
	
	inline public function getMatrix():Mat33
	{
		return mMatrix;
	}
	
	inline public function setMatrix(matrix:Mat33)
	{
		mMatrix.of(matrix);
		mHints &= ~(HINT_IDENTITY | HINT_RS_MATRIX | HINT_IDENTITY_ROTATION | HINT_UNIFORM_SCALE);
		mHints |= HINT_HMATRIX_DIRTY;
	}
	
	inline public function getTranslate():Vec3
	{
		return mTranslate;
	}
	
	inline public function setTranslate(x:Float, y:Float, z:Float)
	{
		mTranslate.x = x;
		mTranslate.y = y;
		mTranslate.z = z;
		mHints &= ~HINT_IDENTITY;
		mHints |= HINT_HMATRIX_DIRTY;
	}
	
	inline public function setTranslate2(x:Float, y:Float)
	{
		mTranslate.x = x;
		mTranslate.y = y;
		mHints &= ~HINT_IDENTITY;
		mHints |= HINT_HMATRIX_DIRTY;
	}
	
	inline public function of(other:Xform):Xform
	{
		mTranslate.of(other.mTranslate);
		mScale.of(other.mScale);
		mMatrix.of(other.mMatrix);
		mHints = other.mHints | HINT_HMATRIX_DIRTY;
		return this;
	}
	
	inline public function of2(other:Xform):Xform
	{
		mTranslate.x = other.mTranslate.x;
		mTranslate.y = other.mTranslate.y;
		
		mScale.x = other.mScale.x;
		mScale.y = other.mScale.y;
		
		var m = mMatrix;
		var o = other.mMatrix;
		m.m11 = o.m11; m.m12 = o.m12;
		m.m21 = o.m21; m.m22 = o.m22;
		
		mHints = other.mHints | HINT_HMATRIX_DIRTY;
		return this;
	}
	
	inline public function setIdentity()
	{
		mMatrix.setIdentity();
		mTranslate.makeZero();
		mScale.x = 1;
		mScale.y = 1;
		mScale.z = 1;
		mHints |= HINT_IDENTITY | HINT_RS_MATRIX | HINT_IDENTITY_ROTATION | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
	}
	inline public function setIdentity2()
	{
		var m = mMatrix;
		m.m11 = 1; m.m12 = 0;
		m.m21 = 0; m.m22 = 1;
		mTranslate.x = 0;
		mTranslate.y = 0;
		mScale.x = 1;
		mScale.y = 1;
		mHints |= HINT_IDENTITY | HINT_RS_MATRIX | HINT_IDENTITY_ROTATION | HINT_UNIT_SCALE | HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
	}
	
	inline public function setUnitScale()
	{
		assert(mHints & HINT_RS_MATRIX > 0, "matrix is not a rotation");
		mScale.x = 1;
		mScale.y = 1;
		mScale.z = 1;
		mHints |= HINT_UNIT_SCALE | HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
	}
	
	inline public function setUnitScale2()
	{
		assert(mHints & HINT_RS_MATRIX > 0, "matrix is not a rotation");
		mScale.x = 1;
		mScale.y = 1;
		mHints |= HINT_UNIT_SCALE | HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
	}
	
	/**
		Matrix-matrix multiplication; returns this = `a` * `b`.
	**/
	public function setProduct(a:Xform, b:Xform):Xform
	{
		if (a.isIdentity())
		{
			of(b);
			return this;
		}
		if (b.isIdentity())
		{
			of(a);
			return this;
		}
		
		mHints = HINT_IDENTITY | HINT_RS_MATRIX | HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
		
		//both transformations are M = R*S, so matrix can be written as R*S*X + T
		if (a.isRSMatrix() && b.isRSMatrix())
		{
			if (a.isUniformScale())
			{
				//R: rA * rB
				if (a.isIdentityRotation())
					mMatrix.of(b.mMatrix);
				else
				if (b.isIdentityRotation())
					mMatrix.of(a.mMatrix);
				else
					Mat33.matrixProduct(a.mMatrix, b.mMatrix, mMatrix);
				
				//T: sA * (rA * tB) + tA
				var t = mTranslate;
				var ta = a.mTranslate;
				if (a.isIdentityRotation())
					t.of(b.mTranslate);
				else
					a.mMatrix.timesVectorConst(b.mTranslate, t);
				var sa = a.getUniformScale();
				t.x = t.x * sa + ta.x;
				t.y = t.y * sa + ta.y;
				t.z = t.z * sa + ta.z;
				
				//S: sA * sB
				if (b.isUniformScale())
					setUniformScale(sa * b.getUniformScale());
				else
				{
					var sb = b.getScale();
					setScale(sa * sb.x, sa * sb.y, sa * sb.z);
				}
				return this;
			}
		}
		
		//the matrix cannot be written as R*S*X+T.
		
		//TODO check if a or b is R=I
		if (a.isRSMatrix() && a.isIdentityRotation())
		{
			trace("A: R=I");
		}
		
		if (b.isRSMatrix() && b.isIdentityRotation())
		{
			trace("B: R=I");
		}
		
		//M: mA * mB
		var ma = (a.isRSMatrix()) ? (a.mMatrix.timesDiagonalConst(a.mScale, _tmpMat1)) : a.mMatrix;
		var mb = (b.isRSMatrix()) ? (b.mMatrix.timesDiagonalConst(b.mScale, _tmpMat2)) : b.mMatrix;
		Mat33.matrixProduct(ma, mb, mMatrix);
		
		//T: mA * tB + tA
		var t = mTranslate;
		ma.timesVectorConst(b.mTranslate, t);
		var ta = a.mTranslate;
		t.x += ta.x;
		t.y += ta.y;
		t.z += ta.z;
		
		//set hints manually as we skip calling setMatrix() or setTranslate()
		mHints &= ~(HINT_IDENTITY | HINT_RS_MATRIX | HINT_UNIFORM_SCALE);
		return this;
	}
	
	public function setProduct2(a:Xform, b:Xform):Xform
	{
		if (a.isIdentity())
		{
			of2(b);
			return this;
		}
		if (b.isIdentity())
		{
			of2(a);
			return this;
		}
		
		mHints = HINT_IDENTITY | HINT_RS_MATRIX | HINT_UNIFORM_SCALE | HINT_HMATRIX_DIRTY;
		
		var m, ma, mb, x, y, t, t1, t2, ta, sa, sb;
		var b11, b12;
		var b21, b22;
		
		//both transformations are M = R*S, so matrix can be written as R*S*X + T
		if (a.isRSMatrix() && b.isRSMatrix() && a.isUniformScale())
		{
			m = mMatrix;
			
			//R: rA * rB
			if (a.isIdentityRotation())
			{
				mb = b.mMatrix;
				m.m11 = mb.m11; m.m12 = mb.m12;
				m.m21 = mb.m21; m.m22 = mb.m22;
				
				if (b.isIdentityRotation()) mHints |= HINT_IDENTITY_ROTATION;
			}
			else
			if (b.isIdentityRotation())
			{
				ma = a.mMatrix;
				m.m11 = ma.m11; m.m12 = ma.m12;
				m.m21 = ma.m21; m.m22 = ma.m22;
				
				setRotate(m);
			}
			else
			{
				ma = a.mMatrix;
				mb = b.mMatrix;
				
				b11 = mb.m11; b12 = mb.m12;
				b21 = mb.m21; b22 = mb.m22;
				t1 = ma.m11;
				t2 = ma.m12;
				m.m11 = t1 * b11 + t2 * b21;
				m.m12 = t1 * b12 + t2 * b22;
				t1 = ma.m21;
				t2 = ma.m22;
				m.m21 = t1 * b11 + t2 * b21;
				m.m22 = t1 * b12 + t2 * b22;
				
				setRotate(m);
			}
			
			//T: sA * (rA * tB) + tA
			t = mTranslate;
			ta = a.mTranslate;
			if (a.isIdentityRotation())
			{
				t.x = b.mTranslate.x;
				t.y = b.mTranslate.y;
			}
			else
			{
				x = b.mTranslate.x;
				y = b.mTranslate.y;
				m = a.mMatrix;
				t.x = m.m11 * x + m.m12 * y;
				t.y = m.m21 * x + m.m22 * y;
			}
			
			sa = a.getUniformScale();
			t.x = t.x * sa + ta.x;
			t.y = t.y * sa + ta.y;
			
			//S: sA * sB
			if (b.isUniformScale())
				setUniformScale2(sa * b.getUniformScale());
			else
			{
				sb = b.getScale();
				setScale2(sa * sb.x, sa * sb.y);
			}
			return this;
		}
		
		//the matrix cannot be written as R*S*X+T.
		
		//M: mA * mB
		ma = a.mMatrix;
		if (a.isRSMatrix())
		{
			ma = _tmpMat1;
			x = a.mScale.x;
			y = a.mScale.y;
			m = a.mMatrix;
			ma.m11 = m.m11 * x; ma.m12 = m.m12 * y;
			ma.m21 = m.m21 * x; ma.m22 = m.m22 * y;
		}
		
		mb = b.mMatrix;
		if (b.isRSMatrix())
		{
			ma = _tmpMat2;
			x = b.mScale.x;
			y = b.mScale.y;
			m = b.mMatrix;
			mb.m11 = m.m11 * x; mb.m12 = m.m12 * y;
			mb.m21 = m.m21 * x; mb.m22 = m.m22 * y;
		}
		
		m = mMatrix;
		b11 = mb.m11; b12 = mb.m12;
		b21 = mb.m21; b22 = mb.m22;
		t1 = ma.m11;
		t2 = ma.m12;
		m.m11 = t1 * b11 + t2 * b21;
		m.m12 = t1 * b12 + t2 * b22;
		t1 = ma.m21;
		t2 = ma.m22;
		m.m21 = t1 * b11 + t2 * b21;
		m.m22 = t1 * b12 + t2 * b22;
		
		//T: mA * tB + tA
		t = mTranslate;
		x = b.mTranslate.x;
		y = b.mTranslate.y;
		t.x = ma.m11 * x + ma.m12 * y;
		t.y = ma.m21 * x + ma.m22 * y;
		
		ta = a.mTranslate;
		t.x += ta.x;
		t.y += ta.y;
		
		//set hints manually as we skip calling setMatrix() or setTranslate()
		mHints &= ~(HINT_IDENTITY | HINT_RS_MATRIX | HINT_UNIFORM_SCALE);
		mHints |= HINT_HMATRIX_DIRTY;
		
		return this;
	}
	
	/**
		Computes Y = RSX + T where X equals `input` and Y `equals` output.
		
		_Note: `input` and `output` can point to the same object._
	**/
	public function applyForward(input:Vec3, output:Vec3):Vec3
	{
		if (isIdentity())
		{
			//Y = X
			output.of(input);
		}
		else
		if (isRSMatrix())
		{
			//Y = R*S*X + T
			output.x = input.x * mScale.x;
			output.y = input.y * mScale.y;
			output.z = input.z * mScale.z;
			
			if (!isIdentityRotation())
				mMatrix.timesVector(output);
			
			output.x += mTranslate.x;
			output.y += mTranslate.y;
			output.z += mTranslate.z;
		}
		else
		{
			//Y = M*X + T
			output.of(input);
			mMatrix.timesVector(output);
			output.x += mTranslate.x;
			output.y += mTranslate.y;
			output.z += mTranslate.z;
		}
		
		return output;
	}
	
	/**
		Note: `input` and `output` can point to the same object.
	**/
	public function applyForward2(input:Coord2f, output:Coord2f):Coord2f
	{
		if (isIdentity())
		{
			//Y = X
			output.x = input.x;
			output.y = input.y;
		}
		else
		if (isRSMatrix())
		{
			//Y = R*S*X + T
			var x = input.x * mScale.x;
			var y = input.y * mScale.y;
			
			if (!isIdentityRotation())
			{
				var t = x;
				var m = mMatrix;
				x = m.m11 * x + m.m12 * y;
				y = m.m21 * t + m.m22 * y;
			}
			
			output.x = x + mTranslate.x;
			output.y = y + mTranslate.y;
		}
		else
		{
			//Y = M*X + T
			var x = input.x;
			var y = input.y;
			var t = x;
			var m = mMatrix;
			x = m.m11 * x + m.m12 * y;
			y = m.m21 * t + m.m22 * y;
			output.x = x + mTranslate.x;
			output.y = y + mTranslate.y;
		}
		return output;
	}
	
	/**
		Same as `applyForward()`, but operates on `numPoints` `input` vectors.
	**/
	public function applyForwardBatch(input:Vector<Vec3>, output:Vector<Vec3>, numPoints:Int):Vector<Vec3>
	{
		if (isIdentity())
		{
			//Y = X
			for (i in 0...numPoints)
				output[i].of(input[i]);
		}
		else
		if (isRSMatrix())
		{
			var inp:Vec3, out:Vec3;
			
			//Y = R*S*X + T
			var sx = mScale.x;
			var sy = mScale.y;
			var sz = mScale.z;
			for (i in 0...numPoints)
			{
				inp = input[i];
				out = output[i];
				out.x = inp.x * sx;
				out.y = inp.y * sy;
				out.z = inp.z * sz;
			}
			
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var tz = mTranslate.z;
			
			if (isIdentityRotation())
			{
				for (i in 0...numPoints)
				{
					out = output[i];
					out.x += tx;
					out.y += ty;
					out.z += tz;
				}
			}
			else
			{
				var m = mMatrix;
				for (i in 0...numPoints)
				{
					out = output[i];
					m.timesVector(out);
					out.x += tx;
					out.y += ty;
					out.z += tz;
				}
			}
		}
		else
		{
			//Y = M*X + T
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var tz = mTranslate.z;
			var m = mMatrix;
			for (i in 0...numPoints)
			{
				var out = output[i];
				out.of(input[i]);
				m.timesVector(out);
				out.x += tx;
				out.y += ty;
				out.z += tz;
			}
		}
		
		return output;
	}
	
	public function applyForwardBatch2(input:Vector<Vec3>, output:Vector<Vec3>, numPoints:Int):Vector<Vec3>
	{
		if (isIdentity())
		{
			//Y = X
			var inp:Vec3, out:Vec3;
			for (i in 0...numPoints)
			{
				inp = input[i];
				out = output[i];
				out.x = inp.x;
				out.y = inp.y;
			}
		}
		else
		if (isRSMatrix())
		{
			var inp:Vec3, out:Vec3;
			
			//Y = R*S*X + T
			var sx = mScale.x;
			var sy = mScale.y;
			for (i in 0...numPoints)
			{
				inp = input[i];
				out = output[i];
				out.x = inp.x * sx;
				out.y = inp.y * sy;
			}
			
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			
			if (isIdentityRotation())
			{
				for (i in 0...numPoints)
				{
					out = output[i];
					out.x += tx;
					out.y += ty;
				}
			}
			else
			{
				var m = mMatrix, t;
				var m11 = m.m11; var m12 = m.m12;
				var m21 = m.m21; var m22 = m.m22;
				
				for (i in 0...numPoints)
				{
					out = output[i];
					t = out.x;
					out.x = (m11 * out.x + m12 * out.y) + ty;
					out.y = (m21 * t     + m22 * out.y) + ty;
				}
			}
		}
		else
		{
			//Y = M*X + T
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var m = mMatrix, t;
			var m11 = m.m11; var m12 = m.m12;
			var m21 = m.m21; var m22 = m.m22;
			for (i in 0...numPoints)
			{
				var out = output[i];
				var inp = input[i];
				t = inp.x;
				out.x = (m11 * inp.x + m12 * inp.y) + ty;
				out.y = (m21 * t     + m22 * inp.y) + ty;
			}
		}
		
		return output;
	}
	
	public function applyForwardBatchf(input:Vector<Float>, output:Vector<Float>, numPoints:Int):Vector<Float>
	{
		if (isIdentity())
		{
			//Y = X
			for (i in 0...numPoints)
			{
				var j = i * 3;
				output[j + 0] = input[j + 0];
				output[j + 1] = input[j + 1];
				output[j + 2] = input[j + 2];
			}
		}
		else
		if (isRSMatrix())
		{
			var inp:Vec3, out:Vec3;
			
			//Y = R*S*X + T
			var sx = mScale.x;
			var sy = mScale.y;
			var sz = mScale.z;
			
			for (i in 0...numPoints)
			{
				var j = i * 3;
				output[j + 0] = input[j + 0] * sx;
				output[j + 1] = input[j + 1] * sy;
				output[j + 2] = input[j + 2] * sy;
			}
			
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var tz = mTranslate.z;
			
			if (isIdentityRotation())
			{
				for (i in 0...numPoints)
				{
					var j = i * 3;
					output[j + 0] += tx;
					output[j + 1] += ty;
					output[j + 2] += tz;
				}
			}
			else
			{
				var m = mMatrix;
				var m11 = m.m11; var m12 = m.m12; var m13 = m.m13;
				var m21 = m.m21; var m22 = m.m22; var m23 = m.m23;
				var m31 = m.m31; var m32 = m.m32; var m33 = m.m33;
				for (i in 0...numPoints)
				{
					var j = i * 3;
					var x = output[j + 0];
					var y = output[j + 1];
					var z = output[j + 2];
					output[j + 0] = (m11 * x + m12 * y + m13 * z) + tx;
					output[j + 1] = (m21 * x + m22 * y + m23 * z) + ty;
					output[j + 2] = (m31 * x + m32 * y + m33 * z) + tz;
				}
			}
		}
		else
		{
			//Y = M*X + T
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var tz = mTranslate.z;
			var m = mMatrix;
			var m11 = m.m11; var m12 = m.m12; var m13 = m.m13;
			var m21 = m.m21; var m22 = m.m22; var m23 = m.m23;
			var m31 = m.m31; var m32 = m.m32; var m33 = m.m33;
			for (i in 0...numPoints)
			{
				var j = i * 3;
				var x = input[j + 0];
				var y = input[j + 1];
				var z = input[j + 2];
				output[j + 0] = (m11 * x + m12 * y + m13 * z) + tx;
				output[j + 1] = (m21 * x + m22 * y + m23 * z) + ty;
				output[j + 2] = (m31 * x + m32 * y + m33 * z) + tz;
			}
		}
		
		return output;
	}
	
	public function applyForwardBatchf2(input:Vector<Float>, output:Vector<Float>, offset:Int, numPoints:Int):Vector<Float>
	{
		if (isIdentity())
		{
			//Y = X
			for (i in 0...numPoints)
			{
				var j = i << 1;
				output[j + 0] = input[offset + j + 0];
				output[j + 1] = input[offset + j + 1];
			}
		}
		else
		if (isRSMatrix())
		{
			var inp:Vec3, out:Vec3;
			
			//Y = R*S*X + T
			var sx = mScale.x;
			var sy = mScale.y;
			
			for (i in 0...numPoints)
			{
				var j = i << 1;
				output[j + 0] = input[offset + j + 0] * sx;
				output[j + 1] = input[offset + j + 1] * sy;
			}
			
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			
			if (isIdentityRotation())
			{
				for (i in 0...numPoints)
				{
					var j = i << 1;
					output[j + 0] += tx;
					output[j + 1] += ty;
				}
			}
			else
			{
				var m = mMatrix;
				var m11 = m.m11; var m12 = m.m12;
				var m21 = m.m21; var m22 = m.m22;
				for (i in 0...numPoints)
				{
					var j = i << 1;
					var x = output[j + 0];
					var y = output[j + 1];
					output[j + 0] = (m11 * x + m12 * y) + tx;
					output[j + 1] = (m21 * x + m22 * y) + ty;
				}
			}
		}
		else
		{
			//Y = M*X + T
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var m = mMatrix;
			var m11 = m.m11; var m12 = m.m12;
			var m21 = m.m21; var m22 = m.m22;
			for (i in 0...numPoints)
			{
				var j = i << 1;
				var x = input[offset + j + 0];
				var y = input[offset + j + 1];
				output[j + 0] = (m11 * x + m12 * y) + tx;
				output[j + 1] = (m21 * x + m22 * y) + ty;
			}
		}
		
		return output;
	}
	
	/**
		Compute `X = S^{-1}*R^{T}*(Y - T)` or `X = M^{-1}*(Y - T)` where Y equals input and X equals output.
	**/
	public function applyInverse(input:Vec3, output:Vec3):Vec3
	{
		if (isIdentity())
		{
			//X = Y
			output.of(input);
		}
		else
		{
			output.x = input.x - mTranslate.x;
			output.y = input.y - mTranslate.y;
			output.z = input.z - mTranslate.z;
			
			if (isRSMatrix())
			{
				//X = S^{-1}*R^{T}*(Y - T)
				if (!isIdentityRotation())
					mMatrix.vectorTimes(output);
				
				if (isUniformScale())
					output.scale(1 / getUniformScale());
				else
				{
					output.x /= mScale.x;
					output.y /= mScale.y;
					output.z /= mScale.z;
				}
			}
			else
			{
				//X = M^{-1}*(Y - T)
				mMatrix.inverseConst(_tmpMat1);
				_tmpMat1.timesVector(output);
			}
		}
		
		return output;
	}
	
	/**
		Note: `input` and `output` can point to the same object.
	**/
	public function applyInverse2(input:Coord2f, output:Coord2f):Coord2f
	{
		if (isIdentity())
		{
			//X = Y
			output.x = input.x;
			output.y = input.y;
		}
		else
		{
			var x = input.x - mTranslate.x;
			var y = input.y - mTranslate.y;
			
			if (isRSMatrix())
			{
				//X = S^{-1}*R^{T}*(Y - T)
				if (!isIdentityRotation())
				{
					var t = x;
					var m = mMatrix;
					x = x * m.m11 + y * m.m21;
					y = t * m.m12 + y * m.m22;
				}
				
				output.x = x / mScale.x;
				output.y = y / mScale.y;
			}
			else
			{
				//X = M^{-1}*(Y - T)
				var m = mMatrix;
				var det = m.m11 * m.m22 - m.m12 * m.m21;
				assert(!M.cmpZero(det, M.ZERO_TOLERANCE), "singular matrix");
				var invDet = 1 / det;
				output.x =  (m.m22 * invDet) * x - (m.m12 * invDet) * y;
				output.y = -(m.m21 * invDet) * x + (m.m11 * invDet) * y;
			}
		}
		return output;
	}
	
	/**
		Same as applyInverse(), but operates on numPoints vectors.
	**/
	public function applyInverseBatch(input:Vector<Vec3>, output:Vector<Vec3>, numPoints:Int):Vector<Vec3>
	{
		if (isIdentity())
		{
			for (i in 0...numPoints)
				output[i].of(input[i]);
		}
		else
		{
			//X = S^{-1}*R^t*(Y - T)
			var inp:Vec3, out:Vec3;
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			var tz = mTranslate.z;
			for (i in 0...numPoints)
			{
				inp = input[i];
				out = output[i];
				out.x = inp.x - mTranslate.x;
				out.y = inp.y - mTranslate.y;
				out.z = inp.z - mTranslate.z;
			}
			
			if (isRSMatrix())
			{
				if (!isIdentityRotation())
				{
					for (i in 0...numPoints)
						mMatrix.vectorTimes(output[i]);
				}
				
				if (isUniformScale())
				{
					var invScale = 1 / getUniformScale();
					for (i in 0...numPoints)
						output[i].scale(invScale);
				}
				else
				{
					var invScaleX = 1 / mScale.x;
					var invScaleY = 1 / mScale.y;
					var invScaleZ = 1 / mScale.z;
					for (i in 0...numPoints)
					{
						out = output[i];
						out.x *= invScaleX;
						out.y *= invScaleY;
						out.z *= invScaleZ;
					}
				}
			}
			else
			{
				//X = M^{-1}*(Y - T)
				var inv = _tmpMat1;
				mMatrix.inverseConst(inv);
				for (i in 0...numPoints)
					inv.timesVector(output[i]);
			}
		}
		
		return output;
	}
	
	public function applyInverseBatch2(input:Vector<Vec3>, output:Vector<Vec3>, numPoints:Int):Vector<Vec3>
	{
		if (isIdentity())
		{
			var inp:Vec3, out:Vec3;
			for (i in 0...numPoints)
			{
				inp = input[i];
				out = output[i];
				out.x = inp.x;
				out.y = inp.y;
			}
		}
		else
		{
			//X = S^{-1}*R^t*(Y - T)
			var inp:Vec3, out:Vec3;
			var tx = mTranslate.x;
			var ty = mTranslate.y;
			for (i in 0...numPoints)
			{
				inp = input[i];
				out = output[i];
				out.x = inp.x - mTranslate.x;
				out.y = inp.y - mTranslate.y;
			}
			
			if (isRSMatrix())
			{
				if (!isIdentityRotation())
				{
					var m = mMatrix;
					var m11 = m.m11; var m12 = m.m12;
					var m21 = m.m21; var m22 = m.m22;
					for (i in 0...numPoints)
					{
						out = output[i];
						var t = out.x;
						out.x = out.x * m11 + out.y * m21;
						out.y = t     * m12 + out.y * m22;
					}
				}
				
				if (isUniformScale())
				{
					var invScale = 1 / getUniformScale();
					for (i in 0...numPoints)
					{
						out = output[i];
						out.x *= invScale;
						out.y *= invScale;
					}
				}
				else
				{
					var invScaleX = 1 / mScale.x;
					var invScaleY = 1 / mScale.y;
					for (i in 0...numPoints)
					{
						out = output[i];
						out.x *= invScaleX;
						out.y *= invScaleY;
					}
				}
			}
			else
			{
				//X = M^{-1}*(Y - T)
				var m = mMatrix;
				var det = m.m11 * m.m22 - m.m12 * m.m21;
				assert(!M.cmpZero(det, M.ZERO_TOLERANCE), "singular matrix");
				var invDet = 1 / det;
				var m11 =  m.m22 * invDet;
				var m12 = -m.m12 * invDet;
				var m21 = -m.m21 * invDet;
				var m22 =  m.m11 * invDet;
				for (i in 0...numPoints)
				{
					out = output[i];
					var t = out.x;
					out.x = m11 * out.x + m12 * out.y;
					out.y = m21 * t     + m22 * out.y;
				}
			}
		}
		
		return output;
	}
	
	/**
		Inverse-transforms the `input` vector. The `output` vector is M^{-1}*input.
	**/
	public function invertVector(input:Vec3, output:Vec3):Vec3
	{
		if (isIdentity())
		{
			//X = Y
			output.of(input);
		}
		else
		if (isRSMatrix())
		{
			//X = S^{-1}*R^{T}*Y
			output.of(input);
			
			if (!isIdentityRotation())
				mMatrix.vectorTimes(output);
			
			if (isUniformScale())
				output.scale(1 / getUniformScale());
			else
			{
				var s = mScale;
				output.x /= s.x;
				output.y /= s.y;
				output.z /= s.z;
			}
		}
		else
		{
			//X = M^{-1}*Y
			var inv = _tmpMat1;
			mMatrix.inverseConst(inv);
			inv.timesVector(output);
		}
		
		return output;
	}
	
	/**
		Computes the inverse transformation.
		
		- if Y = RSX + T, the inverse is X = S^{−1}R^{T}(Y − T).
		- no test is performed to determine whether this transform is invertible.
		- the inverse transformation has scale S^{−1}, rotation R^{T}, and translation −S^{−1}R^{T}T.
	**/
	public function inverseTransform(output:Xform):Xform
	{
		if (isIdentity())
		{
			output.of(this);
			return output;
		}
		
		if (isRSMatrix())
		{
			var invRot =
			if (isIdentityRotation())
				output.mMatrix.of(mMatrix);
			else
				mMatrix.transposeConst(output.mMatrix);
			
			if (isUniformScale())
			{
				var invScale = 1 / mScale.x;
				output.setUniformScale(invScale);
				var invTrn = invRot.timesVectorConst(mTranslate, output.mTranslate);
				invTrn.scale(-invScale);
			}
			else
			{
				var invScaleX = 1 / mScale.x;
				var invScaleY = 1 / mScale.y;
				var invScaleZ = 1 / mScale.z;
				output.setScale(invScaleX, invScaleY, invScaleZ);
				
				var invTrn = invRot.timesVectorConst(mTranslate, output.mTranslate);
				invTrn.x *= -invScaleX;
				invTrn.y *= -invScaleY;
				invTrn.z *= -invScaleZ;
			}
		}
		else
		{
			output.mHints = HINT_HMATRIX_DIRTY;
			var invMat = mMatrix.inverseConst(output.mMatrix);
			var invTrn = invMat.timesVectorConst(mTranslate, output.mTranslate);
			invTrn.flip();
		}
		
		return output;
	}
	
	/**
		For M = R*S, returns the largest absolute value of S.
		For general M, the max-column-sum norm is returned and is guaranteed to be larger than or equal to the largest eigenvalue of S in absolute value.
	**/
	public function getNorm():Float
	{
		if (isRSMatrix())
		{
			//return largest absolute value of S
			var max = M.fabs(mScale.x);
			if (M.fabs(mScale.y) > max) max = M.fabs(mScale.y);
			if (M.fabs(mScale.z) > max) max = M.fabs(mScale.z);
			return max;
		}
		else
		{
			//use the max-row-sum matrix norm for a general matrix;
			var maxRowSum = M.fabs(mMatrix.m11) + M.fabs(mMatrix.m12) + M.fabs(mMatrix.m13);
			var rowSum    = M.fabs(mMatrix.m21) + M.fabs(mMatrix.m22) + M.fabs(mMatrix.m23);
			if (rowSum > maxRowSum) maxRowSum = rowSum;
			rowSum        = M.fabs(mMatrix.m31) + M.fabs(mMatrix.m32) + M.fabs(mMatrix.m33);
			if (rowSum > maxRowSum) maxRowSum = rowSum;
			return maxRowSum;
		}
	}
	
	public function getNorm2():Float
	{
		if (isRSMatrix())
		{
			var maxX = M.fabs(mScale.x);
			var maxY = M.fabs(mScale.y);
			return M.fmax(maxX, maxY);
		}
		else
		{
			var maxRow1 = M.fabs(mMatrix.m11) + M.fabs(mMatrix.m12);
			var maxRow2 = M.fabs(mMatrix.m21) + M.fabs(mMatrix.m22);
			return M.fmax(maxRow1, maxRow2);
		}
	}
	
	//TODO only works if local copy is used!
	//var hMatrix:Mat44 = new Mat44();
	
	/**
		Sets `output` to the 4x4 homogeneous matrix.
	**/
	public function getHMatrix(output:Mat44):Mat44
	{
		var h = output;
		
		//output.of(h);
		
		//TODO HINT_HMATRIX_DIRTY
		//if (mHints & HINT_HMATRIX_DIRTY != 0)
		//{
			mHints &= ~HINT_HMATRIX_DIRTY;
			mHints |= HINT_INVERSE_DIRTY;
			
			//R, T, or S has changed.
			
			if (isIdentity())
			{
				h.m11 = 1; h.m12 = 0; h.m13 = 0; h.m14 = 0;
				h.m21 = 0; h.m22 = 1; h.m23 = 0; h.m24 = 0;
				h.m31 = 0; h.m32 = 0; h.m33 = 1; h.m34 = 0;
			}
			else
			{
				var m = mMatrix;
				
				var sx = mScale.x;
				var sy = mScale.y;
				var sz = mScale.z;
				
				if (isRSMatrix())
				{
					h.m11 = m.m11 * sx;
					h.m12 = m.m12 * sy;
					h.m13 = m.m13 * sz;
					h.m21 = m.m21 * sx;
					h.m22 = m.m22 * sy;
					h.m23 = m.m23 * sz;
					h.m31 = m.m31 * sx;
					h.m32 = m.m32 * sy;
					h.m33 = m.m33 * sz;
				}
				else
				{
					h.m11 = m.m11;
					h.m12 = m.m12;
					h.m13 = m.m13;
					h.m21 = m.m21;
					h.m22 = m.m22;
					h.m23 = m.m23;
					h.m31 = m.m31;
					h.m32 = m.m32;
					h.m33 = m.m33;
				}
				
				h.m14 = mTranslate.x;
				h.m24 = mTranslate.y;
				h.m34 = mTranslate.z;
				
				//the last row of mHMatrix is always (0,0,0,1) for an affine transformation.
			}
		//}
		
		return h;
	}
	
	public function getHMatrix2(output:Mat44):Mat44
	{
		var h = output;
		
		//if (mHints & HINT_HMATRIX_DIRTY != 0)
		//{
			mHints &= ~HINT_HMATRIX_DIRTY;
			mHints |= HINT_INVERSE_DIRTY;
			
			//R, T, or S has changed.
			
			if (isIdentity())
			{
				h.m11 = 1; h.m12 = 0; h.m13 = 0;
				h.m21 = 0; h.m22 = 1; h.m23 = 0;
			}
			else
			{
				var m = mMatrix;
				
				var sx = mScale.x;
				var sy = mScale.y;
				
				if (isRSMatrix())
				{
					h.m11 = m.m11 * sx;
					h.m12 = m.m12 * sy;
					h.m21 = m.m21 * sx;
					h.m22 = m.m22 * sy;
				}
				else
				{
					h.m11 = m.m11;
					h.m12 = m.m12;
					h.m21 = m.m21;
					h.m22 = m.m22;
				}
				
				h.m14 = mTranslate.x;
				h.m24 = mTranslate.y;
				
				//the last row of mHMatrix is always (0,0,0,1) for an affine transformation.
			}
		//}
		
		return h;
	}
}