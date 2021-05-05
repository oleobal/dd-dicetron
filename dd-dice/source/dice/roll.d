module dice.roll;

import std.random;
import std.range;
import std.algorithm.iteration;

long[] rollDice(long number, long die)
{
	return generate!(() => uniform!"[]"(1, die)).takeExactly(number).array;
}
bool[] flipCoins(long number, long die=2)
{
	if (die == 0)
		return false.repeat.takeExactly(number).array;
	if (die == 1)
		return true.repeat.takeExactly(number).array;
	if (die==2)
		return generate!(() => [true, false].choice).takeExactly(number).array;
	throw new Exception("No n-sided coins for now");
	// could be coins with non-equiprobable sides tho
}
