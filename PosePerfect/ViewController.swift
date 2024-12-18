//
//  ViewController.swift
//  PosePerfect
//
//  Created by Ayoola Olaosebikan on 12/11/24.
//


import UIKit


class ViewController: UIViewController {


   override func viewDidLoad() {

       super.viewDidLoad()

       setupTutorialButton()

   }

   

   func setupTutorialButton() {

       let tutorialButton = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"),

                                          style: .plain,

                                          target: self,

                                          action: #selector(showTutorial))
       tutorialButton.tintColor = .red

       navigationItem.rightBarButtonItem = tutorialButton

   }

   

   @objc func showTutorial() {

       let tutorialVC = UIViewController()

       tutorialVC.view.backgroundColor = .white

       

       let scrollView = UIScrollView()

       scrollView.translatesAutoresizingMaskIntoConstraints = false

       tutorialVC.view.addSubview(scrollView)

       

       let contentView = UIView()

       contentView.translatesAutoresizingMaskIntoConstraints = false

       scrollView.addSubview(contentView)

       

       // Title

       let titleLabel = UILabel()

       titleLabel.text = "How to Use PosePerfect"

       titleLabel.font = .systemFont(ofSize: 24, weight: .bold)

       titleLabel.textAlignment = .center

       titleLabel.textColor = .black // Explicitly set text color

       titleLabel.translatesAutoresizingMaskIntoConstraints = false

       contentView.addSubview(titleLabel)

       

       // Tutorial text

       let tutorialLabel = UILabel()

       tutorialLabel.numberOfLines = 0

       tutorialLabel.textColor = .black // Explicitly set text color

       tutorialLabel.text = """

       Welcome to PosePerfect! Here's how to use the app:


       1. Stand in front of your camera where your full body is in the frame

       

       2. A pose outline will appear on screen: this is your target pose

       

       3. Try to match the pose shown in the outline that is moving

       

       4. The outline will move closer as you match the pose more congruently

       

       5. Once you successfully match a pose, you'll advance to the next pose

       

       Available Poses:

       • Front Double Biceps

       • Arnold Pose

       • Side Chest

       • Side Tricep

       

       Keep practicing and have fun perfecting your poses & posture!

       """

       tutorialLabel.font = .systemFont(ofSize: 16)

       tutorialLabel.translatesAutoresizingMaskIntoConstraints = false

       contentView.addSubview(tutorialLabel)

       

       // Close button

       let closeButton = UIButton(type: .system)

       closeButton.setTitle("Got it!", for: .normal)

       closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)

       closeButton.tintColor = .systemBlue // Ensure button is visible

       closeButton.addTarget(self, action: #selector(dismissTutorial), for: .touchUpInside)

       closeButton.translatesAutoresizingMaskIntoConstraints = false

       contentView.addSubview(closeButton)

       

       // Layout constraints

       NSLayoutConstraint.activate([

           scrollView.topAnchor.constraint(equalTo: tutorialVC.view.topAnchor),

           scrollView.leadingAnchor.constraint(equalTo: tutorialVC.view.leadingAnchor),

           scrollView.trailingAnchor.constraint(equalTo: tutorialVC.view.trailingAnchor),

           scrollView.bottomAnchor.constraint(equalTo: tutorialVC.view.bottomAnchor),

           

           contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),

           contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),

           contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),

           contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

           contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

           

           titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),

           titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

           titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

           

           tutorialLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),

           tutorialLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

           tutorialLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

           

           closeButton.topAnchor.constraint(equalTo: tutorialLabel.bottomAnchor, constant: 20),

           closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

           closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)

       ])

       

       tutorialVC.modalPresentationStyle = .pageSheet

       if let sheet = tutorialVC.sheetPresentationController {

           sheet.detents = [.medium(), .large()]

           sheet.prefersGrabberVisible = true

       }

       

       present(tutorialVC, animated: true)

   }

   

   @objc func dismissTutorial() {

       dismiss(animated: true)

   }

}
