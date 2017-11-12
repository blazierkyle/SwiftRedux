//: Playground - noun: a place where people can play

import UIKit
import Foundation

// MARK: - Core Types

// State: Your app's data!
struct AppState {
    var counter: Int
    
    init() {
        counter = 0
    }
}

/*
    Store:
        - Holds app state
        - Contains reducers that respond to actions on the store and
          then notifies subscribers of the updated state
*/
class Store {
    
    var state: AppState
    
    var subscribers = NSHashTable<AnyObject>.weakObjects()
    
    var reducer: AppReducer
    
    init() {
        state = AppState()
        reducer = AppReducer()
    }
    
    func subscribe(_ subscriber: StoreSubscriber) {
        subscribers.add(subscriber)
        subscriber.newState(state: state)
    }
    
    func unsubscribe(_ subscriber: StoreSubscriber) {
        subscribers.remove(subscriber)
    }
    
    // Dispatch actions
    func dispatch(action: Action) {
        let newState = reducer.mainReducer(action: action, state: state)
        // Call any middleware here
        notify(newState: newState)
    }
    
    // Dispatch async actions
    func dispatch(asyncAction: AsyncActionCreator) {
        asyncAction(state) { (actionProvider) in
            guard let action = actionProvider(self.state) else { return }
            self.dispatch(action: action)
        }
    }
    
    // Notify all subscribers of a state change
    func notify(newState: AppState) {
        state = newState
        subscribers.allObjects.forEach { subscriber in
            guard let subscriber = subscriber as? StoreSubscriber else {
                fatalError("Invalid subscriber")
            }
            subscriber.newState(state: newState)
        }
    }
}

/*
    Actions
        - Means of describing a state change that needs to happen
          (but doesn’t modify the state)
*/
enum Action {
    case increaseCounter(byCount: Int)
    case decreaseCounter(byCount: Int)
}

/*
     Reducers
        - Pure functions (testable!)
        - Responds to actions and modifies the state accordingly
        - (by copying the state, mutating values and returning this new state)
*/
protocol Reducer: class {
    func reduce(action: Action, state: AppState?) -> AppState
}

// NOTE: This was taken from Fox OTT - credit to Greg Niemann
class AppReducer {
    var reducers: [Reducer] = []
    
    func mainReducer(action: Action, state: AppState?) -> AppState {
        let state = state ?? AppState()
        
        // execute each reducer on the state to get the final state
        return reducers.reduce(state) { working_state, nextReducer in
            nextReducer.reduce(action: action, state: working_state)
        }
    }
    
    func add(reducer: Reducer) {
        reducers.append(reducer)
    }
    
    func remove(reducer: Reducer) {
        guard let index = reducers.index(where: { (item: Reducer) -> Bool in item === reducer }) else {
            return
        }
        
        reducers.remove(at: index)
    }
}

class CountReducer: Reducer {
    func reduce(action: Action, state: AppState?) -> AppState {
        var state = state ?? AppState()
        
        switch action {
        case .increaseCounter(let count):
            state.counter += count
        case .decreaseCounter(let count):
            state.counter -= count
        }
        
        return state
    }
}

/*
    Subscribers
        - Objects/views that will be notified of any state changes
        - and can update views accordingly
*/
class StoreSubscriber: UIViewController {
    func newState(state: AppState) {
        // Implement in subclass
    }
}

/*
    Action Creators
        - Functions that create actions
        - May involve async tasks, like loading from an API
        - before firing an action
        - (could be an action that updates data or throws an error)
        - Could also return nil to not fire any actions
*/
typealias ActionCreator = (_ state: AppState) -> Action?
typealias AsyncActionCreator = (
    _ state: AppState,
    _ actionCreatorCallback: @escaping ((ActionCreator) -> Void)
    ) -> Void

// MARK: - Demo Implementation

// Our Store variable - declared globally so it can be accessed from anywhere
//  note: this is not always the case
var store = Store()

// Our subscribing view controller
class SubscribingViewController: StoreSubscriber {
    
    var counter = 0
    
    private let _reducer = CountReducer()
    
    override func viewDidLoad() {
        store.reducer.add(reducer: _reducer)
    }
    
    deinit {
        store.reducer.remove(reducer: _reducer)
        store.unsubscribe(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        store.subscribe(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        store.unsubscribe(self)
    }
    
    override func newState(state: AppState) {
        counter = state.counter
    }
    
    func increaseCount() {
        store.dispatch(action: Action.increaseCounter(byCount: 1))
    }
    
    func decreaseCount() {
        store.dispatch(action: Action.decreaseCounter(byCount: 1))
    }
    
    func testAsyncActionCreator() {
        store.dispatch(asyncAction: DataActionCreator.getData())
    }
}

struct DataActionCreator {
    static func getData() -> AsyncActionCreator {
        return { state, completion  in
            Api.shared.getData(completion: { (data, error) in
                completion({ (_) -> Action? in
                    // Once we have our data, return an action
                    //  (or nil if we don't want to fire one)
                    return .increaseCounter(byCount: 5)
                })
            })
        }
    }
}

class Api {
    static let shared = Api()
    func getData(completion: (_ data: Data?, _ error: Error?) -> Void) {
        // Just a dummy function to demo an async call
        completion(nil, nil)
    }
}

// Test it all out!
let testSubscriber = SubscribingViewController()
testSubscriber.viewDidLoad() // add reducer
testSubscriber.viewWillAppear(true) // subscribe to state changes
print("Original counter = \(store.state.counter)")
testSubscriber.increaseCount()
print("Counter after increase action = \(store.state.counter)")
testSubscriber.testAsyncActionCreator()
print("Counter after async action = \(store.state.counter)")
testSubscriber.decreaseCount()
print("Counter after decrease action = \(store.state.counter)")
