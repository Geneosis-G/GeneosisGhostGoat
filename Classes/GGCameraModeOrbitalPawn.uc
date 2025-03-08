class GGCameraModeOrbitalPawn extends GGCameraModeOrbital;

/**
 * Update camera properties (e.g. location and rotation )
 */
function UpdateCamera( Pawn P, GamePlayerCamera cameraActor, float deltaTime, out TViewTarget outVT )
{
	local GGPawn gpawn;
	local vector cameraLocation, cameraDirection, cameraTargetLocation, newTargetLocation;
	local float currentFOV, desiredFOV, newFOV;
	local GGEngine engine;

	// default FOV on viewtarget
	currentFOV = PlayerCamera.GetFOVAngle();
	newFOV = currentFOV;
	desiredFOV = PlayerCamera.DefaultFOV;
	//cameraActor.WorldInfo.Game.Broadcast(cameraActor, "UpdateCamera(" $ P $ ", " $ cameraActor $ ", " $ outVT.Target $ ")");
	engine = GGEngine( class'Engine'.static.GetEngine() );
	if( engine != none && engine.mSettings != none )
	{
		desiredFOV = engine.mSettings.mFOV;
	}

	gpawn = GGPawn( outVT.Target );

	if( gpawn != none  )
	{
		newTargetLocation = gpawn.Location;

		if( gpawn.mIsRagdoll != mPreviousIsRagdoll )
		{
			if( gpawn.mIsRagdoll )
			{
				mTargetRagdollOffset = mTargetLocation - newTargetLocation;
			}

			mPreviousIsRagdoll = gpawn.mIsRagdoll;
		}

		if( mPreviousTerminatingRagdoll != gpawn.mTerminatingRagdoll )
		{
			if( gpawn.mTerminatingRagdoll )
			{
				mTargetRagdollOffset = mTargetLocation - newTargetLocation;
			}

			mPreviousTerminatingRagdoll = gpawn.mTerminatingRagdoll;
		}

		mTargetLocation = newTargetLocation + mTargetRagdollOffset;
		mTargetRagdollOffset = VLerp( mTargetRagdollOffset, vect( 0, 0, 0 ), deltaTime );

		mCurrentZoomDistance = Lerp( mCurrentZoomDistance, mDesiredZoomDistance, deltaTime * 3 );

		cameraTargetLocation = GGGoat(gpawn) != none
							?mTargetLocation + GGGoat(gpawn).mCameraLookAtOffset
							:mTargetLocation + vect(0, 0, 1) * gpawn.GetCollisionHeight();
		cameraDirection = Normal( vector( mDesiredRotation ) );
		cameraLocation = cameraTargetLocation - cameraDirection * mCurrentZoomDistance;

		PreventClipping( GGCamera( cameraActor ), outVT, cameraLocation, cameraTargetLocation, 0.0f );
		UpdatePlayerTransparency( P, cameraLocation, cameraTargetLocation );

		// Linear interpolate the fov
		if( desiredFOV != currentFOV )
		{
			newFOV = desiredFOV;
		}

		AddCameraBounce( outVT.Target, deltaTime, cameraLocation );

		outVT.POV.FOV = newFOV;
		outVT.POV.Location = gpawn.mTerminatingRagdoll ? VInterpTo( cameraActor.Location, cameraLocation, deltaTime, 20.0f ) : cameraLocation;
		outVT.POV.Rotation = mDesiredRotation;
	}

 	// Apply camera modifiers at the end (view shakes for example)
	PlayerCamera.ApplyCameraModifiers( deltaTime, outVT.POV );
}

DefaultProperties
{

}
