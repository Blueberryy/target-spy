/* Copyright Alexander Kromm (mmaulwurff@gmail.com) 2018-2019
 *
 * This file is part of Target Spy.
 *
 * Target Spy is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Target Spy is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Target Spy.  If not, see <https://www.gnu.org/licenses/>.
 */

class m8f_ts_PlayToUiTranslator
{

  play Actor AimTargetWrapper(Actor a) const
  {
    return a.AimTarget();
  }

  play Actor LineAttackTargetWrapper(Actor a, double offsetz) const
  {
    FLineTraceData lineTraceData;
    a.LineTrace(a.angle, 4000.0, a.pitch, 0, offsetz, 0.0, 0.0, lineTraceData);
    return lineTraceData.HitActor;
  }

  play Actor AimLineAttackWrapper(Actor a) const
  {
    FTranslatedLineTarget ftlt;
    a.AimLineAttack(a.angle, 2048.0, ftlt, 0,
                    ALF_CHECKNONSHOOTABLE | ALF_FORCENOSMART);
    return ftlt.linetarget;
  }
  
  play Actor LineAttackNoBlockmapWrapper(Actor a, double offsetz) const
  {
    FLineTraceData lineTraceData;
    a.LineTrace(a.angle, 4000.0, a.pitch, 0, offsetz, 0.0, 0.0, lineTraceData);
    if (lineTraceData.HitType != TRACE_HitActor)
    {
      ThinkerIterator noBlockmapActors = ThinkerIterator.Create();
      Actor nbmActor;
      Actor closestNbmActor;
      while (nbmActor = Actor(noBlockmapActors.Next()))
      {
        if (nbmActor.bNoBlockmap == false) { continue; } else
        {
          //Detect NoBlockmap actors by checking if line from LineTrace intersects sphere they are in.
          //Line equation is:   P = LineStart + Direction * t
          //Sphere equation is: (P - SphereCenter) dot (P - SphereCenter) = SphereRadius * SphereRadius
          
          //Line and Sphere share points (P) if they intersect:
          //Combined equation:  (LineStart + Direction * t - SphereCenter) dot (LineStart + Direction * t - SphereCenter)
          //Same equation rearranged:   t * t * (Direction dot Direction) + 2 * t * (Direction dot (LineStart - SphereCenter)) + ((LineStart - SphereCenter) dot (LineStart - SphereCenter)) - SphereRadius * SphereRadius = 0
          //This is quadratic equation: t * t * a + t * b + c = 0
          
          vector3 SphereCenter = (nbmActor.pos.x, nbmActor.pos.y, nbmActor.pos.z + nbmActor.height/2);
          double  SphereRadius = max(nbmActor.height,nbmActor.radius * 2)/2;
          
          vector3 LineStart = (a.pos.x,a.pos.y,a.pos.z+offsetz);
          vector3 LineEnd   = lineTraceData.HitLocation;
          vector3 Direction = (LineEnd - LineStart).Unit();
          
          //a, b, c of the quadratic equation:
          double a = Direction dot Direction;
          double b = 2 * (Direction dot (LineStart - SphereCenter));
          double c = (LineStart - SphereCenter) dot (LineStart - SphereCenter) - SphereRadius * SphereRadius;
          
          // Line intersects or touches Sphere if t has solutions
          // t has solution(s) if discriminant >= 0
          // discriminant = b * b - 4 * a * c
          // t = ( -b ± sqrt(discriminant) ) / 2 * a
          double discriminant = b * b - 4 * a * c;
          if (discriminant >= 0)
          {
            double t1 = (-b + sqrt(discriminant)) / (2 * a);
            double t2 = (-b - sqrt(discriminant)) / (2 * a);
            //if both of those solutions are positive target is in front of the player
            if (t1 > 0 && t2 > 0)
            {
              //Discard actors that are further than LineEnd (most likely behind the wall)
              if ((LineStart - LineEnd).Length() >= (LineStart - nbmActor.pos).Length())
              {
                //Pick an actor closest to the player
                if (closestNbmActor == NULL) { closestNbmActor = nbmActor; } else
                {
                  if ((LineStart - nbmActor.pos).Length() < (LineStart - closestNbmActor.pos).Length())
                  {
                      closestNbmActor = nbmActor;
                  }
                }
              }
            }
          }
        }
      }
      return closestNbmActor;
    }
    return NULL;
  }

} // class m8f_ts_PlayToUiTranslator