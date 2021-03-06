/* -----------------------------------------------------------------------------
 *
 * (c) The GHC Team 1998-2005
 *
 * Prototypes for functions in Schedule.c 
 * (RTS internal scheduler interface)
 *
 * -------------------------------------------------------------------------*/

#ifndef SCHEDULE_H
#define SCHEDULE_H

#include "OSThreads.h"
#include "Capability.h"

void runTheWorld (HaskellObj closure);

/* initScheduler(), exitScheduler()
 * Called from STG :  no
 * Locks assumed   :  none
 */
void initScheduler (void);
void exitScheduler (rtsBool wait_foreign);

/* raiseExceptionHelper */
StgWord raiseExceptionHelper (StgRegTable *reg, StgTSO *tso, StgClosure *exception);

/* GetRoots(evac_fn f)
 *
 * Call f() for each root known to the scheduler.
 *
 * Called from STG :  NO
 * Locks assumed   :  ????
 */
void GetRoots(evac_fn);

char   *info_type(StgClosure *closure);    // dummy
char   *info_type_by_ip(StgInfoTable *ip); // dummy

/* Flag indicating if any interrupts are pending (and should be handled at the
 * next safe point)
 * Locks required  : none (conflicts are harmless)
 */
extern int pending_irqs;
extern int allow_haskell_interrupts;

/* 
 * flag that tracks whether we have done any execution in this time slice.
 */
#define ACTIVITY_YES      0 /* there has been activity in the current slice */
#define ACTIVITY_MAYBE_NO 1 /* no activity in the current slice */
#define ACTIVITY_INACTIVE 2 /* a complete slice has passed with no activity */
#define ACTIVITY_DONE_GC  3 /* like 2, but we've done a GC too */

/* Recent activity flag.
 * Locks required  : Transition from MAYBE_NO to INACTIVE
 * happens in the timer signal, so it is atomic.  Trnasition from
 * INACTIVE to DONE_GC happens under sched_mutex.  No lock required
 * to set it to ACTIVITY_YES.
 */
extern nat recent_activity;

/* Thread queues.
 * Locks required  : sched_mutex
 *
 * In GranSim we have one run/blocked_queue per PE.
 */
extern  StgTSO *RTS_VAR(blackhole_queue);
#if !defined(THREADED_RTS)
extern  StgTSO *RTS_VAR(blocked_queue_hd), *RTS_VAR(blocked_queue_tl);
extern  StgTSO *RTS_VAR(sleeping_queue);
#endif

/* Set to rtsTrue if there are threads on the blackhole_queue, and
 * it is possible that one or more of them may be available to run.
 * This flag is set to rtsFalse after we've checked the queue, and
 * set to rtsTrue just before we run some Haskell code.  It is used
 * to decide whether we should yield the Capability or not.
 * Locks required  : none (see scheduleCheckBlackHoles()).
 */
extern rtsBool blackholes_need_checking;

/* debugging only 
 */
#ifdef DEBUG
void print_bq (StgClosure *node);
#endif

/* -----------------------------------------------------------------------------
 * Some convenient macros/inline functions...
 */

#if !IN_STG_CODE

/* Add a thread to the end of the blocked queue.
 */
#if !defined(THREADED_RTS)
INLINE_HEADER void
appendToBlockedQueue(StgTSO *tso)
{
    ASSERT(tso->link == END_TSO_QUEUE);
    if (blocked_queue_hd == END_TSO_QUEUE) {
	blocked_queue_hd = tso;
    } else {
	blocked_queue_tl->link = tso;
    }
    blocked_queue_tl = tso;
}
#endif

/* Check whether various thread queues are empty
 */
INLINE_HEADER rtsBool
emptyQueue (StgTSO *q)
{
    return (q == END_TSO_QUEUE);
}

#endif /* !IN_STG_CODE */

INLINE_HEADER void
dirtyTSO (StgTSO *tso)
{
    tso->flags |= TSO_DIRTY;
}

#endif /* SCHEDULE_H */

