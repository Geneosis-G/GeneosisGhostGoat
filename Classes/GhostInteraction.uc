class GhostInteraction extends Interaction;

var GhostGoat myMut;

function InitGhostInteraction(GhostGoat newMut)
{
	myMut=newMut;
}

exec function ReviveGoat(int GoatNumber)
{
	myMut.ReviveGoat(GoatNumber);
}