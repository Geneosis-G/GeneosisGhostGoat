class GhostGoatComponent extends GGMutatorComponent;

var GGPawn me;
var GGGoat gMe;
var GGNpc nMe;
var GGMutator myMut;
var GGGoat body;
var PlayerController myCont;
var float lastSpeed;

var bool isGhost;
var GGGoat lastGhostBody;
var vector lastSpawnLoc;
var bool wasDriving;
var vector movingDirection;
var float ghostSpeed;
var float mGhostAccelRate;
var name mSprintAnim;

var GGNpc controlledNPC;
var bool controllingNPC;
var float oldPanicDuration;
var Controller oldNPCController;
var float oldStandUpDelay;
var float oldJumpZ;
var bool oldUseScriptedRoute;
var array< ProtectInfo > oldProtectItems;
var bool mIsInAir;
var float mAnimEndOffset;
var float mAttackDelay;
var GGBicycleAbstract mBicycle;

var bool canBeGoast;
var bool isGoast;
var float goastFormTime;
var SkeletalMesh mGoastGoatMesh;
var AnimSet mGoastGoatAnimSet;
var AnimTree mGoastGoatAnimTree;
var PhysicsAsset mGoastGoatPhysAsset;
var float mNewCollisionRadius;
var float mNewCollisionHeight;

var SoundCue mSummonSound;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		me=goat;
		gMe=goat;
		body=goat;
		myMut=owningMutator;
		InitMyCont();
	}
}

function InitMyCont()
{
	if(myCont == none || myCont.bPendingDelete)
	{
		myCont=PlayerController(me.Controller);
	}
}

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGPawn gpawn;
	local GGAIController oldAIController;

	gpawn = GGPawn( other );

	if( gpawn != none )
	{
		if(gpawn != me)
		{
			if(me != none)
			{
				//Remove controlled NPC controller
				if(GGNpc(gpawn) != none)
				{
					oldNPCController=gpawn.Controller;
					oldAIController=GGAIController(oldNPCController);
					oldStandUpDelay=GGNpc(gpawn).mStandUpDelay;
					GGNpc(gpawn).mStandUpDelay=1000000;
					oldJumpZ=GGNpc(gpawn).JumpZ;
					GGNpc(gpawn).JumpZ=body.JumpZ;
					oldUseScriptedRoute=gpawn.mUseScriptedRoute;
					gpawn.mUseScriptedRoute=false;
					oldProtectItems=gpawn.mProtectItems;
					gpawn.mProtectItems.Length=0;
					if(oldAIController != none)
					{
						oldPanicDuration=oldAIController.mPanicDuration;
						oldAIController.mPanicDuration=0;
						oldAIController.EndAttack();
						oldAIController.StopAllScheduledMovement();
						oldAIController.GotoState('');
					}
					if(IsZero(gpawn.mesh.Translation) && IsHuman(gpawn))
					{
						gpawn.mesh.SetTranslation(gpawn.default.mesh.Translation);// Fix NPC driver mesh translations
					}
				}
				//Change player controlled pawn
				InitMyCont();
				myCont.Unpossess();//Remove controller from current pawn
				gpawn.SetOwner( myCont );// This keeps the pawn relevant (as said in Vehicle)
				myCont.Possess(gpawn, false);//auto unpossess previous controller of new pawn
				//Reset old NPC controller
				if(nMe != none)
				{
					nMe.mUseScriptedRoute=oldUseScriptedRoute;
					nMe.mStandUpDelay=oldStandUpDelay;
					nMe.JumpZ=oldJumpZ;
					nMe.mProtectItems=oldProtectItems;
					oldAIController=GGAIController(oldNPCController);
					if(oldAIController != none)
					{
						nMe.Controller=none;
						oldAIController.mPanicDuration=oldPanicDuration;
						oldAIController.Possess(nMe, false);
						if(nMe.mIsRagdoll)// Haxx to prevent a glitchy SetRagdoll(false) in GGNpc.Reset()
						{
							nMe.StandUp();
						}
						nMe.mAnimNodeSlot.StopCustomAnim( 0.2f );
						oldAIController.Reset();
					}
					oldNPCController=none;
				}
			}

			me=gpawn;
			gMe=GGGoat(gpawn);
			nMe=GGNpc(gpawn);

			//Fix ghost tongue
			if(gMe != none)
			{
				gMe.FetchTongueControl();
			}

			if(controllingNPC)
			{
				ResetAnim();// Fix anim
			}
			//myMut.WorldInfo.Game.Broadcast(myMut, "Orbital Camera Type=" $ GGCamera( myCont.PlayerCamera ).mCameraModesClasses[CM_ORBIT]);
		}
	}
}

function bool IsHuman(GGPawn gpawn)
{
	local GGAIControllerMMO AIMMO;

	if(InStr(string(gpawn.Mesh.PhysicsAsset), "CasualGirl_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "CasualMan_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "SportyMan_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "HeistNPC_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "Explorer_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "SpaceNPC_Physics") != INDEX_NONE)
	{
		return true;
	}
	AIMMO=GGAIControllerMMO(gpawn.Controller);
	if(AIMMO == none)
	{
		return false;
	}
	else
	{
		return AIMMO.PawnIsHuman();
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local float length;
	local GGPlayerInputGame localInput;

	if(PCOwner != myCont || myCont.Pawn != me)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		//myMut.WorldInfo.Game.Broadcast(myMut, self $ "KeyState: " $ newKey);
		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			if(myMut.WorldInfo.Game.GameSpeed < 1.0f || myMut.WorldInfo.bPlayersOnly)
			{
				if(!isGhost)
				{
					Die();
				}
			}
		}

		if(localInput.IsKeyIsPressed("GBA_Special", string( newKey )))
		{
			if(isGhost)
			{
				if(gMe.mGrabbedItem != none)
				{
					if(GGGoat(gMe.mGrabbedItem) != none || GGNpc(gMe.mGrabbedItem) != none)
					{
						if(PlayerController(Pawn(gMe.mGrabbedItem).Controller) == none)
						{
							Resurect(Pawn(gMe.mGrabbedItem));
						}
					}
				}
			}
		}

		if(localInput.IsKeyIsPressed("GBA_ToggleRagdoll", string( newKey )))
		{
			if(controllingNPC)
			{
				//Switch ragdoll on controlled NPC
				if(controlledNPC.mIsRagdoll)
				{
					StandUpNPC();
				}
				else
				{
					controlledNPC.SetRagdoll(true);
				}
			}
			if(isGhost)
			{
				SummonBody();
			}
		}

		if(localInput.IsKeyIsPressed("GBA_Sprint", string( newKey )))
		{
			if(controllingNPC)
			{
				//Make controlled NPC sprint
				GGPlayerControllerGame(controlledNPC.Controller).mIsSprinting=true;
			}
		}

		if(localInput.IsKeyIsPressed("GBA_AbilityAuto", string( newKey )))
		{
			if(controllingNPC && !me.mIsRagdoll)
			{
				//Make controlled NPC attack
				if(GGNpcGoat(controlledNPC) == none)
				{
					if(!controlledNPC.isCurrentAnimationInfoStruct( controlledNPC.mAttackAnimationInfo ))
					{
						length=controlledNPC.SetAnimationInfoStruct( controlledNPC.mAttackAnimationInfo );
						myMut.WorldInfo.Game.SetTimer(length-mAnimEndOffset, false, NameOf(ResetAnim), self);
					}
				}
				else
				{
					if(controlledNPC.mAnimNodeSlot.GetPlayedAnimation() != 'Ram')
					{
						length=controlledNPC.mAnimNodeSlot.PlayCustomAnim( 'Ram', 1.0f, 0.1f, 0.3f );
						myMut.WorldInfo.Game.SetTimer(length-mAnimEndOffset, false, NameOf(ResetAnim), self);
					}
				}
				myMut.ClearTimer(NameOf(Attack), self);
				myMut.SetTimer(mAttackDelay, false, NameOf(Attack), self);
			}
		}

		if(localInput.IsKeyIsPressed("GBA_AbilityBite", string( newKey )))
		{
			if(controllingNPC)
			{
				//Make controlled NPC applaud
				if(!controlledNPC.isCurrentAnimationInfoStruct( controlledNPC.mApplaudAnimationInfo ))
				{
					length=controlledNPC.SetAnimationInfoStruct( controlledNPC.mApplaudAnimationInfo );
					myMut.WorldInfo.Game.SetTimer(length-mAnimEndOffset, false, NameOf(ResetAnim), self);
				}
			}
		}

		if(localInput.IsKeyIsPressed("GBA_Special", string( newKey )))
		{
			if(controllingNPC)
			{
				//Make controlled NPC dance
				if(!controlledNPC.isCurrentAnimationInfoStruct( controlledNPC.mDanceAnimationInfo ))
				{
					controlledNPC.SetAnimationInfoStruct( controlledNPC.mDanceAnimationInfo );
				}
			}
		}

		if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
		{
			if(controllingNPC)
			{
				//Make controlled NPC Baa or scream
				if(GGNpcGoat(controlledNPC) == none)
				{
					controlledNPC.PlaySoundFromAnimationInfoStruct( controlledNPC.mPanicAnimationInfo );
					if(!controlledNPC.isCurrentAnimationInfoStruct( controlledNPC.mPanicAtWallAnimationInfo ))
					{
						length=controlledNPC.SetAnimationInfoStruct( controlledNPC.mPanicAtWallAnimationInfo );
						myMut.WorldInfo.Game.SetTimer(length-mAnimEndOffset, false, NameOf(ResetAnim), self);
					}
				}
				else
				{
					GGNpcGoat(controlledNPC).PlayBaa();
				}
			}
		}

		if(localInput.IsKeyIsPressed("GBA_Jump", string( newKey )))
		{
			if(controllingNPC)
			{
				//Switch ragdoll on controlled NPC
				if(controlledNPC.mIsRagdoll)
				{
					if(!controlledNPC.mIsInWater)
					{
						StandUpNPC();
					}
					else
					{
						DoRagdollJump();
					}
				}
				else
				{
					if(!mIsInAir)
					{
						controlledNPC.DoJump( true );
					}
				}
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_Forward", string( newKey ) ) )
		{
			movingDirection.X=1.f;
		}
		if( localInput.IsKeyIsPressed( "GBA_Back", string( newKey ) ) )
		{
			movingDirection.X=-1.f;
		}
		if( localInput.IsKeyIsPressed( "GBA_Right", string( newKey ) ) )
		{
			movingDirection.Y=1.f;
		}
		if( localInput.IsKeyIsPressed( "GBA_Left", string( newKey ) ) )
		{
			movingDirection.Y=-1.f;
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("GBA_Sprint", string( newKey )))
		{
			if(controllingNPC)
			{
				//Stop controlled NPC sprint
				GGPlayerControllerGame(controlledNPC.Controller).mIsSprinting=false;
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_Forward", string( newKey ) ) )
		{
			movingDirection.X=0.f;
		}
		if( localInput.IsKeyIsPressed( "GBA_Back", string( newKey ) ) )
		{
			movingDirection.X=0.f;
		}
		if( localInput.IsKeyIsPressed( "GBA_Right", string( newKey ) ) )
		{
			movingDirection.Y=0.f;
		}
		if( localInput.IsKeyIsPressed( "GBA_Left", string( newKey ) ) )
		{
			movingDirection.Y=0.f;
		}
	}
}

event ResetAnim()
{
	local bool useFallingAnim;

	if(controllingNPC)
	{
		if(myMut.IsTimerActive(NameOf(ResetAnim), self))
		{
			return;
		}

		useFallingAnim=IsAnimInSet('Falling', me);
		if(useFallingAnim)
		{
			if(mIsInAir)
			{
				if(controlledNPC.mAnimNodeSlot.GetPlayedAnimation() != 'Falling')
				{
					controlledNPC.mAnimNodeSlot.PlayCustomAnim( 'Falling', 1.0f, 0.2f, 0.2f, true, true);
				}
			}
			else
			{
				if(controlledNPC.mAnimNodeSlot.GetPlayedAnimation() == 'Falling')
				{
					controlledNPC.mAnimNodeSlot.StopCustomAnim( 0.2f );
				}
			}
		}
		if(!mIsInAir || !useFallingAnim)
		{
			if(Vsize2D(controlledNPC.Velocity) == 0.f)
			{
				if(!controlledNPC.isCurrentAnimationInfoStruct( controlledNPC.mIdleAnimationInfo ))
				{
					controlledNPC.SetAnimationInfoStruct( controlledNPC.mIdleAnimationInfo );
				}
			}
			else
			{
				if(!controlledNPC.isCurrentAnimationInfoStruct( controlledNPC.mRunAnimationInfo ))
				{
					controlledNPC.SetAnimationInfoStruct(controlledNPC.mRunAnimationInfo);
				}
			}
		}
	}
}

/**
 * Do ragdoll jump, e.g. for jumping out of water.
 */
function DoRagdollJump()
{
	local vector newVelocity;

	newVelocity = controlledNPC.mesh.GetRBLinearVelocity();
	newVelocity.Z = body.mRagdollJumpZ;

	controlledNPC.mesh.SetRBLinearVelocity( newVelocity );
}

function StandUpNPC()
{
	if(mIsInAir || controlledNPC.mIsInWater)
		return;

	controlledNPC.StandUp();
}

function SummonBody()
{
	if(!isGhost
	|| body==none
	|| body.bPendingDelete
	|| body.Controller != none
	|| !body.mIsRagdoll
	|| body.Physics != PHYS_RigidBody)
		return;

	body.mesh.SetRBLinearVelocity(vect(0, 0, 0));
	body.mesh.SetRBAngularVelocity(vect(0, 0, 0));
	body.SetPhysics(PHYS_None);
	body.mesh.SetRBPosition(me.Location);
	//body.Velocity=vect(0, 0, 0);
	body.SetPhysics(PHYS_RigidBody);
	gMe.PlaySound(mSummonSound);
}

function Attack()
{
	local GGAbility ability;
	local vector direction, headLocation;
	local array< Actor > attackVictims;
	local int i;

	if(!controllingNPC || me.mIsRagdoll)
		return;

	ability=body.mAbilities[ EAT_Horn ];

	headLocation=me.mesh.GetPosition() + Normal(vector(me.Rotation)) * me.GetCollisionRadius();

	direction = vector( me.Rotation );

	attackVictims = DealDirectionalDamage( ability.mDamage, ability.mRange, ability.mDamageTypeClass, ability.mDamageTypeClass.default.mDamageImpulse * body.mAttackMomentumMultiplier, headLocation, direction, myCont );
	for( i = 0; i < attackVictims.Length; i++ )
	{
		GGGameInfo( myMut.WorldInfo.Game ).OnUseAbility( me, ability, attackVictims[ i ] );
	}
}

/**
 * Deals a directional damage within a radius.
 *
 * @param direction - in which direction should the impulse be given.
 * @return - The actor that was damaged, if any
 */
simulated function array< Actor > DealDirectionalDamage
(
	float               baseDamage,
	float               damageRadius,
	class<DamageType>   damageType,
	float               momentum,
	vector              hurtOrigin,
	vector              direction,
	optional Controller instigatedByController = myCont
)
{
	local Actor victim;
	local array< Actor > victims;
	local TraceHitInfo hitInfo;
	local StaticMeshComponent hitComponent;
	local KActorFromStatic newKActor;
	local vector hitLocation, hitNormal;
	local vector hitDir, traceStart, traceEnd;

	foreach myMut.VisibleCollidingActors( class'Actor', victim, damageRadius, hurtOrigin,,,,, hitInfo )
	{
		if( victim.bWorldGeometry )
		{
			// check if it can become dynamic
			hitComponent = StaticMeshComponent( hitInfo.HitComponent );
			if( ( hitComponent != None ) && hitComponent.CanBecomeDynamic() )
			{
				newKActor = class'KActorFromStatic'.Static.MakeDynamic( hitComponent );
				if( newKActor != None )
				{
					victim = newKActor;
					hitInfo.HitComponent = newKActor.StaticMeshComponent;
				}
			}
		}
		if( !victim.bWorldGeometry && ( victim != me ) )
		{
			GGGameInfo( myMut.WorldInfo.Game ).OnCollision( me, victim );

			victims.AddItem( victim );

			traceEnd = hitInfo.HitComponent.Bounds.Origin;
			hitDir = traceEnd - hurtOrigin;
			traceStart = hurtOrigin - hitDir * 0.3f;

			traceEnd += hitDir * 0.3f;

			myMut.TraceComponent( hitLocation, hitNormal, hitInfo.HitComponent, traceEnd, traceStart,, hitInfo, false );

			victim.TakeDamage( baseDamage, instigatedByController, hitLocation, momentum * direction, damageType, hitInfo, me );
		}
	}

	return victims;
}

/*
 * Bugfix
 */
function Tick( float deltaTime )
{
	local vector camLocation, movementDir;
	local rotator camRotation;
	local float currSpeed;
	local bool wasInAir;
	local bool isDriving;

	InitMyCont();
	if(myCont == none)
		return;
	//Try to fix possess done somewhere else in the code
	if(isGhost && myCont.Pawn != lastGhostBody)
	{
		OnPlayerRespawn(myCont, false);
	}

	currSpeed=VSize(me.Velocity);
	isDriving=(GGSVehicle(me.DrivenVehicle) != none);
	if(isGhost)
	{
		//Fix ghost not appearing at the correct place???
		if(!IsZero(lastSpawnLoc))
		{
			if(me.Location != lastSpawnLoc)
			{
				me.SetLocation(lastSpawnLoc);
			}
			lastSpawnLoc=vect(0, 0, 0);
		}
		//myMut.WorldInfo.Game.Broadcast(myMut, "Phys=" $ me.Physics $ ", AI state=" $ myCont.GetStateName());
		if(GGLocalPlayer(myCont.Player).mIsUsingGamePad)
		{
			// aBaseY & aStrafe do NOT WORK in TickMutatorComponent ?!?$#%
			//myMut.WorldInfo.Game.Broadcast(myMut, "aBaseY=" $ PlayerController( me.Controller ).PlayerInput.aBaseY);
			//myMut.WorldInfo.Game.Broadcast(myMut, "aStrafe=" $ PlayerController( me.Controller ).PlayerInput.aStrafe);
			movingDirection.X=myCont.PlayerInput.aBaseY;
			movingDirection.Y=myCont.PlayerInput.aStrafe;
		}
		if(!IsZero(movingDirection) && GGSVehicle(gMe.DrivenVehicle) == none)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "ghostSpeed=" $ ghostSpeed $ ", mGhostAccelRate=" $ mGhostAccelRate $ ", deltaTime=" $ deltaTime);
			if(ghostSpeed < gMe.mSprintSpeed)
			{
				ghostSpeed=FMin(ghostSpeed + mGhostAccelRate * deltaTime, gMe.mSprintSpeed);
			}
			//myMut.WorldInfo.Game.Broadcast(myMut, "new ghostSpeed=" $ ghostSpeed);
			GGPlayerControllerGame( myCont ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
			movementDir=Normal(movingDirection >> camRotation);
			//me.DrawDebugLine( me.Location, me.Location + movementDir * 100.f, 255, 0, 0, false );
			me.SetLocation(me.Location + (movementDir * deltaTime * ghostSpeed));
			if( gMe.mAnimNodeSlot.GetPlayedAnimation() != mSprintAnim )
			{
				gMe.mAnimNodeSlot.PlayCustomAnim( mSprintAnim, 1.0f, 0.1f, 0.3f, true, true);
			}
		}
		else
		{
			if( gMe.mAnimNodeSlot.GetPlayedAnimation() == mSprintAnim )
			{
				gMe.mAnimNodeSlot.StopCustomAnim(0.3f);
			}
			ghostSpeed=0.f;
		}
	}

	//Fix driving problems
	if(!isDriving && wasDriving)
	{
		//myMut.WorldInfo.Game.Broadcast(myMut, "End driving");
		if(isGhost)
		{
			SetGhostModePhysics(gMe);
		}
		else if(controllingNpc)//Fix NPC mesh translation
		{
			controlledNPC.mesh.SetTranslation(controlledNPC.default.mesh.Translation);
			MakeNpcBiker(false);
		}
	}
	if(!wasDriving && isDriving)
	{
		//Fix bycicle anim for NPCs
		if(controllingNpc && GGBicycleAbstract(me.DrivenVehicle) != none)
		{
			MakeNpcBiker(true);
		}

		//Fix anim while driving
		if(controllingNpc
		&& !(nMe.mAnimNodeSlot.GetPlayedAnimation() == 'Biker')
		&& !(nMe.mAnimNodeSlot.GetPlayedAnimation() == 'idlecar_01')
		&& !(nMe.mAnimNodeSlot.GetPlayedAnimation() == 'IdlePassenger_01'))
		{
			nMe.mAnimNodeSlot.StopCustomAnim( 0.2f );
		}
	}


	//Fix falling ghost problems
	if(isGhost && me.Physics != PHYS_None)
	{
		SetGhostModePhysics(gMe);
	}

	//Control NPC
	if(controllingNPC)
	{
		//If the NPC have been destroyed for some reason
		if(controlledNPC == none || controlledNPC.bPendingDelete || PlayerController(controlledNPC.controller) != myCont)
		{
			Die();
		}
		else
		{
			//Fix Sprint for controllers
			if(GGLocalPlayer(myCont.Player).mIsUsingGamePad)
			{
				GGPlayerControllerGame(myCont).mIsSprinting=(myCont.PlayerInput.aBaseY > 0.9f);
			}

			//Fix in air state
			wasInAir=mIsInAir;
			CollectNPCAirInfo();

			//Fix anims
			if((wasInAir && !mIsInAir)
			|| (!wasInAir && mIsInAir)
			|| (currSpeed == 0.f && lastSpeed != 0.f)
			|| (currSpeed != 0.f && lastSpeed == 0.f))
			{
				ResetAnim();
			}
		}
		//Fix bicycle driving
		if(mBicycle != none)
		{
			AdaptBikerSpeed();
		}
		//WorldInfo.Game.Broadcast(self, "mGroundSpeedForward : " $ nMe.mGroundSpeedForward);
		//WorldInfo.Game.Broadcast(self, "mGroundSpeedReverse : " $ nMe.mGroundSpeedReverse);
		//WorldInfo.Game.Broadcast(self, "mGroundSpeedStrafe : " $ nMe.mGroundSpeedStrafe);
		//WorldInfo.Game.Broadcast(self, "JumpZ : " $ nMe.JumpZ);
	}

	//Enable/disable Goast form
	if(!IsZero(me.Velocity))
	{
		if(myMut.WorldInfo.Game.IsTimerActive(NameOf(EnableGoastForm), self))
		{
			myMut.WorldInfo.Game.ClearTimer(NameOf(EnableGoastForm), self);
		}
		if(canBeGoast)
		{
			canBeGoast=false;
		}
	}
	if(!isGhost && !canBeGoast && !myMut.WorldInfo.Game.IsTimerActive(NameOf(EnableGoastForm), self) && IsZero(me.Velocity))
	{
		myMut.WorldInfo.Game.SetTimer(goastFormTime, false, NameOf(EnableGoastForm), self);
	}
	lastSpeed=currSpeed;
	wasDriving=isDriving;
	//myMut.WorldInfo.Game.Broadcast(myMut, "canBeGoast=" $ canBeGoast);
	//myMut.WorldInfo.Game.Broadcast(myMut, "me.Velocity=" $ me.Velocity);
}

function MakeNpcBiker(bool activate)
{
	local vector newTranslation;

	if(activate)
	{
		if(IsAnimInSet('Biker', nMe))
		{
			mBicycle=GGBicycleAbstract(me.DrivenVehicle);
			mBicycle.mesh.bUpdateSkelWhenNotRendered = true;
			newTranslation=GGNpcGoat(nMe)!=none?vect(40, 0, -50):vect(40, 0, 0);
			nMe.mesh.SetTranslation(newTranslation);// Offset the user to get the correct position
			nMe.mAnimNodeSlot.PlayCustomAnim( 'Biker', 0.1f, , , true );
		}
	}
	else if(mBicycle != none)
	{
		nMe.mAnimNodeSlot.StopCustomAnim( 0.1f );
		nMe.mesh.GlobalAnimRateScale = 1.0f;
		mBicycle.Mesh.bUpdateSkelWhenNotRendered = false;
		mBicycle=none;
	}
}

function AdaptBikerSpeed()
{
	local int speedRatio;
	local float bikerRate;

	speedRatio = mBicycle.ForwardVel / 10.0f;
	if( speedRatio > 0 || speedRatio < 0 )
	{
		// Only play biker animation if the pedals are going.
		bikerRate = ( mBicycle.Throttle != 0 ) ? ( speedRatio ) * mBicycle.mBikerSpeedFactor : 0.01f;

		// Beware! This is a bit dangerous, scince this var scales anim rate for all animations on the mesh
		// It must be reset when leaving the bike. Used since I could not find a way of increasing rate on an animation already playing
		nMe.mesh.GlobalAnimRateScale = bikerRate;
	}
}

function CollectNPCAirInfo()
{
	local vector hitLocation, hitNormal;
	local vector traceStart, traceEnd, traceExtent;
	local float traceOffsetZ, distanceToGround;
	local Actor hitActor;

	traceExtent = controlledNPC.GetCollisionExtent() * 0.75f;
	traceExtent.Y = traceExtent.X;
	traceExtent.Z = traceExtent.X;

	traceOffsetZ = traceExtent.Z + 10.0f;
	traceStart = controlledNPC.mesh.GetPosition() + vect( 0.0f, 0.0f, 1.0f ) * traceOffsetZ;
	traceEnd = traceStart - vect( 0.0f, 0.0f, 1.0f ) * 100000.0f;

	hitActor = me.Trace( hitLocation, hitNormal, traceEnd, traceStart,, traceExtent );
	if(hitActor == none)
	{
		hitLocation=traceEnd;
	}

	distanceToGround = FMax( VSize( traceStart - hitLocation ) - controlledNPC.GetCollisionHeight() - traceOffsetZ, 0.0f );

	mIsInAir = !controlledNPC.mIsInWater && ( controlledNPC.Physics == PHYS_Falling || ( controlledNPC.Physics == PHYS_RigidBody && distanceToGround > body.mIsInAirThreshold ) );
}

/**
 * Kill the goat or the NPC and turn it into a ghost
 */
function Die()
{
	local PostProcessSettings pps;
	local LocalPlayer localPlayer;
	local GGGoat ghost;
	local GGPawn lastBody;
	local vector spawnLoc;
	local rotator spawnRot;

	//myMut.WorldInfo.Game.Broadcast(myMut, self $ "Try Die");
	if(isGhost || (me != none && me.DrivenVehicle != none) || myCont == none)
		return;
	//Emergency delete in case the ghost body was still there
	if(lastGhostBody != none)
	{
		lastGhostBody.DropGrabbedItem();
		lastGhostBody.Destroy();
		lastGhostBody=none;
	}

	//myMut.WorldInfo.Game.Broadcast(myMut, self $ "Die OK");
	localPlayer=LocalPlayer(myCont.Player);

	//Ghost visual effect
	if(canBeGoast)
	{
		isGoast=true;
	}
	else
	{
		pps.bEnableBloom=false;
		pps.bOverride_Scene_Desaturation = true;
		pps.Scene_Desaturation = 1.0;
		localPlayer.OverridePostProcessSettings(pps, 0.0);
	}

	lastBody=me;
	if(gMe != none)
	{
		gMe.DropGrabbedItem();
	}
	controllingNPC=false;

	//Create ghost
	spawnLoc=lastBody!=none
			?lastBody.mesh.GetPosition() + vect(0, 0, 1) * lastBody.GetCollisionHeight() * 2.f
			:body.mesh.GetPosition() + vect(0, 0, 1) * body.GetCollisionHeight() * 2.f;
	spawnRot=lastBody!=none?lastBody.Rotation:body.Rotation;
	ghost = myMut.Spawn(body.class,,, spawnLoc, spawnRot,, true);
	lastSpawnLoc=spawnLoc;
	if(isGoast)
	{
		ActivateGoastForm(ghost);
	}
	else
	{
		CopyCurrentForm(ghost);
	}
	mSprintAnim='Sprint';
	if(!IsAnimInSet(mSprintAnim, ghost))
	{
		mSprintAnim='Sprint_01';
		if(!IsAnimInSet(mSprintAnim, ghost))
		{
			mSprintAnim='Sprint_02';
			if(!IsAnimInSet(mSprintAnim, ghost))
			{
				mSprintAnim='Run';
				if(!IsAnimInSet(mSprintAnim, ghost))
				{
					mSprintAnim='Walk';
				}
			}
		}
	}
	ghost.StopBaa();
	ghost.PlayBaa();

	isGhost=true;
	ModifyPlayer(ghost);
	SetGhostModePhysics(ghost);

	//Make old body die
	if(lastBody != none)
	{
		lastBody.SetRagdoll(true);
	}
	controlledNPC=none;
	lastGhostBody=ghost;
	//myMut.WorldInfo.Game.Broadcast(myMut, "lastBody.Controller=" $ lastBody.Controller);
}

function bool IsAnimInSet(name animName, GGPawn gpawn)
{
	local AnimSequence animSeq;

	foreach gpawn.mesh.AnimSets[0].Sequences(animSeq)
	{
		if(animSeq.SequenceName == animName)
		{
			return true;
		}
	}

	return false;
}

function CopyCurrentForm(GGGoat ghost)
{
	if(body != none && body.mesh.SkeletalMesh != ghost.mesh.SkeletalMesh)
	{
		ghost.mNeckBoneName = body.mNeckBoneName;
		ghost.mFreeFallAnim = body.mFreeFallAnim;

		ghost.mesh.SetSkeletalMesh( body.mesh.SkeletalMesh );
		ghost.mesh.SetPhysicsAsset( body.mesh.PhysicsAsset );
		ghost.mesh.SetAnimTreeTemplate( body.mesh.AnimTreeTemplate );
		ghost.mesh.AnimSets = body.mesh.AnimSets;

		ghost.SetLocation( mGoat.Location + vect( 0.0f, 0.0f, 1.0f ) * (body.GetCollisionHeight() - ghost.GetCollisionHeight()) );
		ghost.SetCollisionSize( body.GetCollisionRadius(), body.GetCollisionHeight() );

		ghost.mCameraLookAtOffset = body.mCameraLookAtOffset;

		ghost.mWalkSpeed = body.mWalkSpeed;
		ghost.mStrafeSpeed = body.mStrafeSpeed;
		ghost.mReverseSpeed = body.mReverseSpeed;
		ghost.mSprintSpeed = body.mSprintSpeed;
		ghost.GroundSpeed = body.GroundSpeed;

		ghost.CustomGravityScaling = body.CustomGravityScaling;

		ghost.mAbilities = body.mAbilities;

		ghost.mDriverPosOffsetX = body.mDriverPosOffsetX;
		ghost.mDriverPosOffsetZ = body.mDriverPosOffsetZ;
		ghost.VehicleCheckRadius = body.VehicleCheckRadius;

		ghost.mBoneScaleInfos=body.mBoneScaleInfos;
	}

	GGGrabbableActorInterface(ghost).SetNewMaterial(ghost.mTransparentMaterial);
}

/**
 * Resurect the goat
 */
function Resurect(Pawn newBody)
{
	//myMut.WorldInfo.Game.Broadcast(myMut, self $ "Try Res");
	if(!isGhost || myCont == none || me.DrivenVehicle != none
	|| (GGGoat(newBody) == none && GGNpc(newBody) == none))
	{
		return;
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, self $ "Res OK");

	if(lastGhostBody != none)
	{
		lastGhostBody.DropGrabbedItem();
		lastGhostBody.Destroy();
		lastGhostBody=none;
	}
	isGhost=false;
	//Ghost to goat transition
	if(GGGoat(newBody) != none)
	{
		ModifyPlayer(GGGoat(newBody));
	}
	//Ghost to NPC transition
	if(GGNpc(newBody) != none)
	{
		controllingNPC=true;
		controlledNPC=GGNpc(newBody);
		ModifyPlayer(controlledNPC);
	}
	if(!isGoast)
	{
		LocalPlayer(myCont.Player).ClearPostProcessSettingsOverride(2.0);
	}
	isGoast=false;
}

/**
 * Called when a player respawns
 */
function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	local GhostGoat ghostGoat;
	local GhostGoatComponent ghostComp;

	InitMyCont();
	//myMut.WorldInfo.Game.Broadcast(myMut, self $ " respawnController=" $ respawnController $ ", myCont=" $ myCont $ ", isGhost=" $ isGhost);
	if(respawnController == myCont)
	{
		//if a ghost try to respawn, send it to his base body
		if(isGhost)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, self $ " ghost respawn detected");
			if(body.Controller != none)
			{
				foreach myMut.AllActors(class'GhostGoat', ghostGoat)
				{
					if(ghostGoat != none)
					{
						foreach ghostGoat.mGhostGoatComponents(ghostComp)
						{
							if(ghostComp != none && ghostComp.gMe == body)
							{
								ghostComp.Die();
								break;
							}
						}
						if(body.Controller == none)
						{
							break;
						}
					}
				}
			}

			Resurect(body);
		}
		//if a NPC respawn, make it ghost
		else if(controllingNPC)
		{
			Die();
		}
	}

	super.OnPlayerRespawn(respawnController, died);
}

function NotifyOnPossess( Controller C, Pawn P )
{
	if( C == myCont )
	{
		//myMut.WorldInfo.Game.Broadcast(myMut, C $ " possess " $ P);
		ModifyCameraZoom( GGGoat(P) );
		TryRegisterInput( PlayerController( C ) );
	}
}

function NotifyOnUnpossess( Controller C, Pawn P )
{
	if( C == myCont )
	{
		//myMut.WorldInfo.Game.Broadcast(myMut, C $ " unpossess " $ P);
		ResetCameraZoom( C );
		TryUnregisterInput( PlayerController( C ) );
	}
}

/*
 * Ragdoll management
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	super.OnRagdoll(ragdolledActor, isRagdoll);

	if(ragdolledActor == me)
	{
		if(isRagdoll)
		{
			//Ghosts can't ragdoll
			if(isGhost)
			{
				gMe.SetRagdoll(false);
				SetGhostModePhysics(gMe);
			}
		}
		else
		{
			if(controllingNPC)
			{
				ResetAnim();
			}
		}
	}
}

/*
 * Apply correct phisics properties for a ghost
 */
function SetGhostModePhysics(GGGoat ghost)
{
	if(myCont == none)
		return;

	ghost.CheatGhost();

	ghost.bCanBeDamaged=false;
	ghost.bBlockActors=false;

	ghost.mesh.SetNotifyRigidBodyCollision( false );
	ghost.mesh.SetTraceBlocking( false, false );
	ghost.mesh.SetHasPhysicsAssetInstance( false );

	ghost.SetPhysics(PHYS_None);
}

function EnableGoastForm()
{
	canBeGoast=true;
}

function ActivateGoastForm(GGGoat goat)
{
	goat.mesh.SetSkeletalMesh( mGoastGoatMesh );
	goat.mesh.SetPhysicsAsset( mGoastGoatPhysAsset );
	goat.mesh.SetAnimTreeTemplate( mGoastGoatAnimTree );
	goat.mesh.AnimSets[ 0 ] = mGoastGoatAnimSet;

	goat.SetLocation( goat.Location + vect( 0.0f, 0.0f, 1.0f ) * ( mNewCollisionHeight - goat.GetCollisionHeight() ) );
	goat.SetCollisionSize( mNewCollisionRadius, mNewCollisionHeight );

	goat.mWalkSpeed = 300;
	goat.mStrafeSpeed = 200;
	goat.mReverseSpeed = 250;
	goat.mSprintSpeed = 800;
	goat.GroundSpeed = goat.mWalkSpeed;

	goat.mAbilities[ EAT_Horn ].mRange = 80.0f;
	goat.mAbilities[ EAT_Horn ].mDamage = 300.0f;
	goat.mAbilities[ EAT_Kick ].mRange = 80.0f;
	goat.mAbilities[ EAT_Kick ].mDamage = 300.0f;
	goat.mAbilities[ EAT_Bite ].mRange = 100.0f;

	goat.ClearBoneScaleInfos();
	goat.AddBoneScaleInfo( 'Head', 2.5f, 3.0f );
	goat.AddBoneScaleInfo( 'Tail_01', 1.5f, 2.0f );
	goat.AddBoneScaleInfo( 'Wing_L_03', 1.2f, 1.8f );
	goat.AddBoneScaleInfo( 'Wing_R_03', 1.2f, 1.8f );
	goat.AddBoneScaleInfo( 'Toe_L', 2.5f, 3.5f );
	goat.AddBoneScaleInfo( 'Toe_R', 2.5f, 3.5f );
}

defaultproperties
{
	goastFormTime=5.f
	mGhostAccelRate=1000.f
	mAnimEndOffset=0.0f
	mAttackDelay=0.2f

	mGoastGoatMesh=SkeletalMesh'Goast.Mesh.Goast_01'
    mGoastGoatAnimSet=AnimSet'Goast.Anim.Goast_Anim_01'
    mGoastGoatAnimTree=AnimTree'Goast.Anim.Goast_AnimTree'
    mGoastGoatPhysAsset=PhysicsAsset'Goast.Mesh.Goast_Physics_01'

    mSummonSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Genie_Spells_Spawn_Cue'

    mNewCollisionRadius=30.0f
    mNewCollisionHeight=62.0f
}