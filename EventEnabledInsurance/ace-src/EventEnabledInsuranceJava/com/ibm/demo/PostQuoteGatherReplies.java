package com.ibm.demo;

import com.ibm.broker.javacompute.MbJavaComputeNode;
import com.ibm.broker.plugin.MbElement;
import com.ibm.broker.plugin.MbException;
import com.ibm.broker.plugin.MbJSON;
import com.ibm.broker.plugin.MbMessage;
import com.ibm.broker.plugin.MbMessageAssembly;
import com.ibm.broker.plugin.MbOutputTerminal;
import com.ibm.broker.plugin.MbUserException;

public class PostQuoteGatherReplies extends MbJavaComputeNode {
	
	public static byte[] hexStringToByteArray(String s) {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                 + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }

	public void evaluate(MbMessageAssembly inAssembly) throws MbException {
		MbOutputTerminal out = getOutputTerminal("out");
		MbOutputTerminal alt = getOutputTerminal("alternate");

		MbMessage inMessage = inAssembly.getMessage();
		MbMessageAssembly outAssembly = null;
		
		MbMessage outMessage1 = new MbMessage(inMessage);
        MbMessage outMessage2 = new MbMessage(inMessage);
        MbMessage outMessage3 = new MbMessage(inMessage);
		
		try {
			// create new message as a copy of the input
			MbMessage outMessage = new MbMessage(inMessage);
			outAssembly = new MbMessageAssembly(inAssembly, outMessage);
			// ----------------------------------------------------------
			// Add user code below

			MbElement outRoot = outMessage.getRootElement();
            outRoot.getLastChild().delete();
            MbElement outJsonRoot = outRoot.createElementAsLastChild(MbJSON.PARSER_NAME);
            MbElement outJsonData = outJsonRoot.createElementAsLastChild(MbElement.TYPE_NAME, MbJSON.DATA_ELEMENT_NAME, null);
            outJsonData.copyElementTree(inAssembly.getLocalEnvironment().getRootElement().getFirstElementByPath("WrittenDestination/GroupScatter"));
            
            // new below here
                        
            MbElement Requests = outMessage.getRootElement().getFirstElementByPath("JSON/Data/Requests");
            // First child of Requests is ReplyId which carries the CorrelId we are after!
            // Last child of Requests is FolderName which carries the important bit of the queue name we are after!
            // First propagation            
            outMessage1.getRootElement().getFirstElementByPath("MQMD/CorrelId").setValue(hexStringToByteArray(Requests.getFirstChild().getValueAsString()));
            MbMessageAssembly outAssembly1 = new MbMessageAssembly(inAssembly,outMessage1);
            MbElement LocalEnv1 = outAssembly1.getLocalEnvironment().getRootElement();
            MbElement MQ1 = LocalEnv1.createElementAsLastChild(MbElement.TYPE_NAME, "MQ", null);
            MbElement GET1 = MQ1.createElementAsLastChild(MbElement.TYPE_NAME, "GET", null);
            GET1.createElementAsLastChild(MbElement.TYPE_NAME_VALUE, "QueueName", Requests.getLastChild().getValue()+"Out");
            out.propagate(outAssembly1);
            
            // Second propagation           
            outMessage2.getRootElement().getFirstElementByPath("MQMD/CorrelId").setValue(hexStringToByteArray(Requests.getNextSibling().getFirstChild().getValueAsString()));         
            MbMessageAssembly outAssembly2 = new MbMessageAssembly(inAssembly,outMessage2);         
            outAssembly2.getLocalEnvironment().getRootElement().getFirstElementByPath("MQ/GET/QueueName").setValue(Requests.getNextSibling().getLastChild().getValue()+"Out");
            out.propagate(outAssembly2);            
            // Third propagation
            outMessage3.getRootElement().getFirstElementByPath("MQMD/CorrelId").setValue(hexStringToByteArray(Requests.getNextSibling().getNextSibling().getFirstChild().getValueAsString()));
            MbMessageAssembly outAssembly3 = new MbMessageAssembly(inAssembly,outMessage3);         
            outAssembly2.getLocalEnvironment().getRootElement().getFirstElementByPath("MQ/GET/QueueName").setValue(Requests.getNextSibling().getNextSibling().getLastChild().getValue()+"Out");         
            out.propagate(outAssembly3);
			
			// End of user code
			// ----------------------------------------------------------
		} catch (MbException e) {
			// Re-throw to allow Broker handling of MbException
			throw e;
		} catch (RuntimeException e) {
			// Re-throw to allow Broker handling of RuntimeException
			throw e;
		} catch (Exception e) {
			// Consider replacing Exception with type(s) thrown by user code
			// Example handling ensures all exceptions are re-thrown to be handled in the flow
			throw new MbUserException(this, "evaluate()", "", "", e.toString(),
					null);
		}
		// The following should only be changed
		// if not propagating message to the 'out' terminal
		out.propagate(outAssembly);

	}

	/**
	 * onPreSetupValidation() is called during the construction of the node
	 * to allow the node configuration to be validated.  Updating the node
	 * configuration or connecting to external resources should be avoided.
	 *
	 * @throws MbException
	 */
	@Override
	public void onPreSetupValidation() throws MbException {
	}

	/**
	 * onSetup() is called during the start of the message flow allowing
	 * configuration to be read/cached, and endpoints to be registered.
	 *
	 * Calling getPolicy() within this method to retrieve a policy links this
	 * node to the policy. If the policy is subsequently redeployed the message
	 * flow will be torn down and reinitialized to it's state prior to the policy
	 * redeploy.
	 *
	 * @throws MbException
	 */
	@Override
	public void onSetup() throws MbException {
	}

	/**
	 * onStart() is called as the message flow is started. The thread pool for
	 * the message flow is running when this method is invoked.
	 *
	 * @throws MbException
	 */
	@Override
	public void onStart() throws MbException {
	}

	/**
	 * onStop() is called as the message flow is stopped. 
	 *
	 * The onStop method is called twice as a message flow is stopped. Initially
	 * with a 'wait' value of false and subsequently with a 'wait' value of true.
	 * Blocking operations should be avoided during the initial call. All thread
	 * pools and external connections should be stopped by the completion of the
	 * second call.
	 *
	 * @throws MbException
	 */
	@Override
	public void onStop(boolean wait) throws MbException {
	}

	/**
	 * onTearDown() is called to allow any cached data to be released and any
	 * endpoints to be deregistered.
	 *
	 * @throws MbException
	 */
	@Override
	public void onTearDown() throws MbException {
	}

}
