module dice.roll;

import std.random;
import std.range;
import std.algorithm.iteration;

long[] rollDice(long number, long die)
{
	return generate!(() => uniform!"[]"(1, die)).takeExactly(number).array;
}
bool[] flipCoins(long number)
{
	return generate!(() => [true, false].choice).takeExactly(number).array;
}
