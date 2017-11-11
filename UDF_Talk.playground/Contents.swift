//: Playground - noun: a place where people can play

import UIKit
import Foundation

struct AppState {
    var counter: Int
    
    init() {
        counter = 0
    }
}

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
    
    func dispatch(action: Action) {
        let newState = reducer.mainReducer(action: action, state: state)
        // Call any middleware here
        notify(newState: newState)
        
    }
    
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

enum Action {
    case increaseCounter(byCount: Int)
    case decreaseCounter(byCount: Int)
}

protocol Reducer: class {
    func reduce(action: Action, state: AppState?) -> AppState
}

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

class StoreSubscriber: UIViewController {
    func newState(state: AppState) {
        // Override in subclass
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

var store = Store()

class SubscribingViewController: StoreSubscriber {
    
    var counter = 0
    
    override func viewDidLoad() {
        store.reducer.add(reducer: CountReducer())
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
}

// Test it all out!
let testSubscriber = SubscribingViewController()
testSubscriber.viewDidLoad()
testSubscriber.viewWillAppear(true) // subscribe to state changes
testSubscriber.increaseCount()
print("Counter = \(store.state.counter)")
